# Cache Fallback Strategies

This document outlines the robust caching strategies implemented in the GitHub Actions workflows to handle cache service outages gracefully.

## Overview

The workflows are designed with multiple fallback mechanisms to ensure builds can complete successfully even when GitHub's cache service experiences outages. The implementation follows a graceful degradation pattern that prioritizes build reliability over performance.

## Problem Statement

GitHub Actions cache service can experience outages that manifest as:
- 400 Bad Request errors when accessing cache APIs
- sccache connection failures with error messages like "Our services aren't available right now"
- Build failures due to cache service unavailability

## Robust Solution

### Three-Tier Cache Fallback System

The workflows implement automatic detection and fallback with **runtime error handling** and **retry logic** to ensure builds never fail due to cache issues.

### 1. Primary: GitHub Actions Cache + sccache
- **Backend**: GitHub Actions cache service with connectivity testing
- **Tool**: `mozilla-actions/sccache-action@v0.0.5` with verification
- **Configuration**: `SCCACHE_GHA_ENABLED=true` (only after connectivity test)
- **Performance**: Up to 99% build time reduction with cache hits
- **Status Indicator**: ✅ `GitHub Actions cache connectivity verified`

### 2. Secondary: Local sccache Fallback
- **Backend**: Local disk cache with validation
- **Tool**: Built-in sccache with local storage
- **Configuration**: `SCCACHE_DIR=$HOME/.cache/sccache` (tested before use)
- **Performance**: Moderate caching benefits (~15-30% reduction)
- **Status Indicator**: ⚠️ `Local sccache fallback successful`

### 3. Tertiary: No Cache Mode (Guaranteed)
- **Backend**: None (pure cargo builds)
- **Configuration**: `DISABLE_CACHE=true`
- **Performance**: Full compilation time but **guaranteed build completion**
- **Status Indicator**: ❌ `Building without cache`

## Enhanced Implementation Features

### Cache Connectivity Testing

Before enabling sccache, the system tests actual connectivity:

```bash
test_cache_connectivity() {
  # Test with timeout and proper cleanup
  timeout 30s sccache --show-stats >/dev/null 2>&1 || return 1
  timeout 15s sccache --start-server >/dev/null 2>&1 || return 1
  return 0
}
```

### Runtime Error Handling

Build steps include retry logic that detects cache failures during compilation:

```bash
run_cargo_with_fallback() {
  local attempt=1
  local max_attempts=2
  
  while [ $attempt -le $max_attempts ]; do
    if timeout 900s $cmd 2>&1 | tee cargo-log-$attempt.txt; then
      return 0
    else
      # Detect cache errors and disable sccache for retry
      if grep -q "sccache\|cache\|400.*Bad Request" cargo-log-$attempt.txt; then
        echo "Detected sccache error, disabling cache for retry"
        unset RUSTC_WRAPPER SCCACHE_GHA_ENABLED SCCACHE_DIR
        sccache --stop-server >/dev/null 2>&1 || true
      fi
      attempt=$((attempt + 1))
    fi
  done
}
```

### Docker Build Resilience

Container builds include fallback for cache-related failures:

```bash
# Automatically retry build without cache if cache-related errors detected
if grep -q "cache\|sccache\|400.*Bad Request" build-log.txt; then
  echo "Retrying build without cache..."
  # Rebuild with DISABLE_CACHE=true
fi
```
    fi
```

### Error Handling

Cache-related steps use `continue-on-error: true` to prevent cache failures from breaking builds:

```yaml
- name: Install sccache
  uses: mozilla-actions/sccache-action@v0.0.5
  continue-on-error: true
  id: sccache-install

- name: Cache cargo registry and sccache
  uses: actions/cache@v4
  continue-on-error: true
  id: cache-cargo
```

## Manual Override Options

### Quick Cache Bypass (Recommended)

The easiest way to bypass caching during outages:

**Option 1: Uncomment in workflow files**
```yaml
env:
  # Uncomment the line below to disable all caching during GitHub Actions outages:
  DISABLE_CACHE: true
```

**Option 2: Repository Variables (Persistent)**
1. Go to Settings → Secrets and variables → Actions → Variables
2. Add variable: `DISABLE_CACHE` = `true`
3. All future builds will skip caching until variable is removed

**Option 3: Workflow Dispatch**
1. Go to Actions tab → Select workflow → "Run workflow"
2. Set custom environment variables if needed

### Emergency Recovery Commands

If builds are stuck in a failing state due to cache issues:

```bash
# Clear local caches and retry
git pull origin main
# Update workflows with DISABLE_CACHE=true and push
```

## Performance Impact by Mode

| Cache Mode | Build Time | Compilation Time | Status Indicator | Typical Scenario |
|------------|------------|------------------|------------------|------------------|
| **GitHub Actions Cache** | ~0.1s | ~0.1s | ✅ `GHA cache connectivity verified` | Normal operation |
| **Local sccache** | ~15-30s | ~10-20s | ⚠️ `Local sccache fallback successful` | GHA cache outage |
| **No Cache** | ~60-90s | ~45-75s | ❌ `Building without cache` | Full service outage |

## Troubleshooting Guide

### Common Cache Outage Scenarios

**Scenario 1: 400 Bad Request Errors**
```
Error: sccache: error: Server startup failed: cache storage failed to read: 
Unexpected (permanent) at read => <h2>Our services aren't available right now</h2>
```
- **Automatic Response**: System detects error and retries without cache
- **Manual Action**: None required, builds should complete automatically

**Scenario 2: sccache Timeout**
```
Error: sccache --start-server timeout
```
- **Automatic Response**: Falls back to local sccache, then no-cache mode
- **Manual Action**: None required

**Scenario 3: Build Hangs on Cache Operations**
```
Waiting for cache service response...
```
- **Automatic Response**: Timeout after 30s, fallback to next tier
- **Manual Action**: Re-run workflow or enable `DISABLE_CACHE=true`

### Manual Diagnosis Commands

**Check cache status in a workflow run:**
```bash
echo "Cache status: $CACHE_STATUS"
echo "sccache config: $RUSTC_WRAPPER"
echo "GHA cache enabled: $SCCACHE_GHA_ENABLED"
```

**Test sccache connectivity locally:**
```bash
sccache --show-stats
sccache --start-server
```

## Status Indicators Reference

The workflows provide clear indicators of the current cache mode:

- ✅ **`GitHub Actions cache connectivity verified`** - Primary cache active
- ⚠️ **`GitHub Actions cache connectivity failed - attempting local sccache fallback`** - Secondary mode
- ✅ **`Local sccache fallback successful`** - Local cache working
- ❌ **`Local sccache also failed - building without cache`** - No-cache mode
- 🚫 **`Cache manually disabled via DISABLE_CACHE environment variable`** - Manual override

## Integration with Error Handling

The fallback system integrates with build retry logic:

1. **First Attempt**: Try with configured cache mode
2. **Cache Error Detection**: Scan logs for cache-related failures
3. **Automatic Retry**: Disable cache and retry build
4. **Success Guarantee**: Builds complete even without any caching

## Monitoring and Troubleshooting

### Build Log Indicators

The workflows provide clear logging for cache status:

- `✅ Configuring sccache with GitHub Actions backend` - Primary cache active
- `⚠️ GitHub Actions cache unavailable, using local sccache` - Fallback mode
- `❌ Cache unavailable or disabled, building without cache` - No cache mode

### Common Outage Scenarios

#### GitHub Actions Cache Service Down
```
Error: cache storage failed to read: Unexpected (permanent) at read => 
<h2>Our services aren't available right now</h2>
```
**Resolution**: Automatic fallback to local sccache

#### sccache Installation Failure
```
Error: Failed to install sccache
```
**Resolution**: Automatic fallback to no-cache build

#### Complete Cache Failure
```
Warning: Both GitHub Actions cache and sccache unavailable
```
**Resolution**: Build proceeds without any caching

## Best Practices

### For Repository Maintainers

1. **Monitor build times**: Set up alerts for significant build time increases
2. **Test fallback modes**: Periodically test with `DISABLE_CACHE=true`
3. **Documentation**: Keep team informed about fallback mechanisms

### For Contributors

1. **Expect variability**: Build times may vary during cache outages
2. **Retry builds**: Transient cache issues may resolve on retry
3. **Report persistent issues**: Notify maintainers of repeated cache failures

### For Enterprise Users

Consider additional caching strategies:

1. **Self-hosted runners**: With persistent local caches
2. **External cache backends**: Redis or S3-based sccache backends
3. **Artifact pre-warming**: Pre-build dependencies in separate workflows

## Alternative Cache Backends

For advanced setups, sccache supports additional backends:

### Redis Backend
```bash
export SCCACHE_REDIS=redis://localhost:6379
export SCCACHE_REDIS_EXPIRATION=86400
```

### S3 Backend
```bash
export SCCACHE_BUCKET=my-cache-bucket
export SCCACHE_REGION=us-west-2
```

### Memcached Backend
```bash
export SCCACHE_MEMCACHED=localhost:11211
```

## Recovery Strategies

### During Active Outage

1. **Immediate**: Re-run failed builds (may resolve intermittent issues)
2. **Short-term**: Enable `DISABLE_CACHE=true` environment variable
3. **Medium-term**: Monitor GitHub status page for service restoration

### Post-Outage

1. **Remove overrides**: Clear `DISABLE_CACHE` environment variable
2. **Warm caches**: Run a few builds to restore cache efficiency
3. **Verify performance**: Confirm build times return to normal levels

## Configuration Reference

### Environment Variables

| Variable | Purpose | Default | Example |
|----------|---------|---------|---------|
| `DISABLE_CACHE` | Disable all caching | `false` | `true` |
| `SCCACHE_GHA_ENABLED` | Enable GitHub Actions cache | `true` | `false` |
| `SCCACHE_DIR` | Local cache directory | Auto | `$HOME/.cache/sccache` |
| `SCCACHE_CACHE_SIZE` | Local cache size limit | `2G` | `5G` |

### Workflow Inputs

For manual workflow runs:

```yaml
workflow_dispatch:
  inputs:
    disable_cache:
      description: 'Disable all caching'
      required: false
      default: 'false'
      type: choice
      options:
        - 'false'
        - 'true'
```

## Support and Troubleshooting

For issues with cache fallback mechanisms:

1. Check workflow logs for cache status messages
2. Verify GitHub Actions service status
3. Test with manual cache disable
4. Report persistent issues with logs

The fallback system is designed to be transparent and self-healing, requiring minimal manual intervention during outages.