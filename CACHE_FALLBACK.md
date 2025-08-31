# Cache Fallback Strategies

This document outlines the robust caching strategies implemented in the GitHub Actions workflows to handle cache service outages gracefully.

## Overview

The workflows are designed with multiple fallback mechanisms to ensure builds can complete successfully even when GitHub's cache service experiences outages. The implementation follows a graceful degradation pattern that prioritizes build reliability over performance.

## Cache Fallback Hierarchy

### 1. Primary: GitHub Actions Cache + sccache
- **Backend**: GitHub Actions cache service
- **Tool**: `mozilla-actions/sccache-action@v0.0.5`
- **Configuration**: `SCCACHE_GHA_ENABLED=true`
- **Performance**: Up to 99% build time reduction with cache hits

### 2. Secondary: Local sccache
- **Backend**: Local disk cache
- **Tool**: Built-in sccache with local storage
- **Configuration**: `SCCACHE_DIR=$HOME/.cache/sccache`
- **Performance**: Moderate caching benefits within the same job

### 3. Tertiary: No Cache (Fallback)
- **Backend**: None
- **Configuration**: `DISABLE_CACHE=true`
- **Performance**: Full compilation time but guaranteed build completion

## Implementation Details

### Automatic Fallback Logic

The workflows automatically detect cache service availability and configure appropriate fallback:

```yaml
- name: Configure sccache with fallback
  run: |
    # Check if sccache installation and cache are available
    if [ "${{ steps.sccache-install.outcome }}" = "success" ] && [ "${{ env.DISABLE_CACHE }}" != "true" ]; then
      echo "✅ Configuring sccache with GitHub Actions backend"
      echo "SCCACHE_GHA_ENABLED=true" >> $GITHUB_ENV
      echo "RUSTC_WRAPPER=sccache" >> $GITHUB_ENV
    elif command -v sccache >/dev/null 2>&1 && [ "${{ env.DISABLE_CACHE }}" != "true" ]; then
      echo "⚠️  GitHub Actions cache unavailable, using local sccache"
      echo "SCCACHE_DIR=$HOME/.cache/sccache" >> $GITHUB_ENV
      echo "SCCACHE_CACHE_SIZE=2G" >> $GITHUB_ENV
      echo "RUSTC_WRAPPER=sccache" >> $GITHUB_ENV
      mkdir -p $HOME/.cache/sccache
    else
      echo "❌ Cache unavailable or disabled, building without cache"
      echo "DISABLE_CACHE=true" >> $GITHUB_ENV
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

### 1. Disable All Caching

To temporarily disable all caching during widespread outages:

```yaml
env:
  DISABLE_CACHE: true
```

Or set as a repository variable for persistent disable.

### 2. Force No-Cache Build

Trigger builds without cache by adding the environment variable:

```bash
# In workflow dispatch or repository settings
DISABLE_CACHE=true
```

### 3. Manual Workflow Run

Use GitHub's workflow dispatch feature with cache override:

1. Go to Actions tab in GitHub
2. Select the workflow
3. Click "Run workflow"
4. Set environment variables as needed

## Performance Impact by Mode

| Cache Mode | Build Time | Compilation Time | Typical Scenario |
|------------|------------|------------------|------------------|
| GitHub Actions Cache | ~0.1s | ~0.1s | Normal operation |
| Local sccache | ~15-30s | ~10-20s | GHA cache outage |
| No Cache | ~60-90s | ~45-75s | Full service outage |

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