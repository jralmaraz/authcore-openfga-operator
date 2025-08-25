#!/bin/bash

# deploy-demos-docker.sh - Deploy OpenFGA demo applications using Docker Compose
# Compatible with Linux, macOS, and Windows (with WSL)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
ENV_FILE="$PROJECT_ROOT/.env.docker"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command_exists docker; then
        log_error "Docker is not installed. Please install Docker first."
        echo "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose is not available."
        echo "Please install Docker Compose or use a newer version of Docker with built-in Compose."
        exit 1
    fi
    
    # Determine compose command
    if command_exists docker-compose; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    log_success "Prerequisites check passed"
    log_info "Using: $COMPOSE_CMD"
}

# Create environment file
create_env_file() {
    log_info "Creating environment configuration..."
    
    cat > "$ENV_FILE" << EOF
# OpenFGA Demo Applications Environment Configuration
# Generated on $(date)

# Banking Application Configuration
BANKING_STORE_ID=
BANKING_AUTH_MODEL_ID=

# GenAI RAG Agent Configuration  
GENAI_STORE_ID=
GENAI_AUTH_MODEL_ID=

# Optional: OpenAI API Key for real AI responses
# OPENAI_API_KEY=your-openai-api-key-here

# Development settings
COMPOSE_PROJECT_NAME=openfga-demos
EOF

    log_success "Environment file created: $ENV_FILE"
    log_info "You can edit this file to customize configuration"
}

# Build and start services
start_services() {
    log_info "Building and starting demo services..."
    
    cd "$PROJECT_ROOT"
    
    # Build images
    log_info "Building container images..."
    $COMPOSE_CMD --env-file "$ENV_FILE" build --no-cache
    
    # Start services
    log_info "Starting services..."
    $COMPOSE_CMD --env-file "$ENV_FILE" up -d
    
    log_success "Services started successfully"
}

# Wait for services to be healthy
wait_for_services() {
    log_info "Waiting for services to be healthy..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Health check attempt $attempt/$max_attempts..."
        
        # Check OpenFGA
        if curl -sf http://localhost:8080/healthz >/dev/null 2>&1; then
            log_success "OpenFGA is healthy"
        else
            log_warning "OpenFGA not ready yet..."
            sleep 10
            ((attempt++))
            continue
        fi
        
        # Check Banking App
        if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
            log_success "Banking app is healthy"
        else
            log_warning "Banking app not ready yet..."
            sleep 10
            ((attempt++))
            continue
        fi
        
        # Check GenAI App
        if curl -sf http://localhost:8001/health >/dev/null 2>&1; then
            log_success "GenAI RAG agent is healthy"
        else
            log_warning "GenAI RAG agent not ready yet..."
            sleep 10
            ((attempt++))
            continue
        fi
        
        log_success "All services are healthy!"
        return 0
    done
    
    log_error "Services did not become healthy within expected time"
    log_info "Check service logs: $COMPOSE_CMD logs"
    return 1
}

# Setup demo data
setup_demo_data() {
    log_info "Setting up demo data..."
    
    # Banking app setup
    log_info "Setting up banking app demo data..."
    if $COMPOSE_CMD --env-file "$ENV_FILE" exec -T banking-app npm run setup 2>/dev/null; then
        log_success "Banking app demo data setup complete"
        
        # Extract store and model IDs for banking app
        local banking_store_id banking_auth_model_id
        banking_store_id=$($COMPOSE_CMD --env-file "$ENV_FILE" exec -T banking-app node -e "
            const fs = require('fs');
            try {
                const config = JSON.parse(fs.readFileSync('.openfga-config.json', 'utf8'));
                console.log(config.storeId || '');
            } catch(e) { console.log(''); }
        " 2>/dev/null || echo "")
        
        banking_auth_model_id=$($COMPOSE_CMD --env-file "$ENV_FILE" exec -T banking-app node -e "
            const fs = require('fs');
            try {
                const config = JSON.parse(fs.readFileSync('.openfga-config.json', 'utf8'));
                console.log(config.authModelId || '');
            } catch(e) { console.log(''); }
        " 2>/dev/null || echo "")
        
        if [[ -n "$banking_store_id" ]] && [[ -n "$banking_auth_model_id" ]]; then
            # Update environment file
            sed -i.bak "s/BANKING_STORE_ID=.*/BANKING_STORE_ID=$banking_store_id/" "$ENV_FILE"
            sed -i.bak "s/BANKING_AUTH_MODEL_ID=.*/BANKING_AUTH_MODEL_ID=$banking_auth_model_id/" "$ENV_FILE"
            log_info "Banking app configuration updated in $ENV_FILE"
        fi
    else
        log_warning "Banking app demo data setup failed - this is normal if OpenFGA is still starting"
    fi
    
    # GenAI app setup
    log_info "Setting up GenAI RAG agent demo data..."
    if $COMPOSE_CMD --env-file "$ENV_FILE" exec -T genai-rag-agent python setup.py 2>/dev/null; then
        log_success "GenAI RAG agent demo data setup complete"
    else
        log_warning "GenAI RAG agent demo data setup failed - this is normal if OpenFGA is still starting"
    fi
    
    log_info "Demo data setup completed"
    log_info "Note: You may need to restart services if setup failed:"
    log_info "  $COMPOSE_CMD --env-file $ENV_FILE restart"
}

# Show service status
show_status() {
    log_info "Service Status:"
    echo
    
    cd "$PROJECT_ROOT"
    $COMPOSE_CMD --env-file "$ENV_FILE" ps
    echo
    
    log_info "Service Health:"
    echo
    
    # Test OpenFGA
    if curl -sf http://localhost:8080/healthz >/dev/null 2>&1; then
        echo "✅ OpenFGA API: http://localhost:8080 (Healthy)"
    else
        echo "❌ OpenFGA API: http://localhost:8080 (Unhealthy)"
    fi
    
    # Test Banking App
    if curl -sf http://localhost:3001/health >/dev/null 2>&1; then
        echo "✅ Banking App: http://localhost:3001 (Healthy)"
    else
        echo "❌ Banking App: http://localhost:3001 (Unhealthy)"
    fi
    
    # Test GenAI App
    if curl -sf http://localhost:8001/health >/dev/null 2>&1; then
        echo "✅ GenAI RAG Agent: http://localhost:8001 (Healthy)"
    else
        echo "❌ GenAI RAG Agent: http://localhost:8001 (Unhealthy)"
    fi
    
    echo
}

# Print access instructions
print_access_instructions() {
    echo
    log_success "Demo applications deployed successfully with Docker Compose!"
    echo
    echo "=================================================="
    echo "            ACCESS INSTRUCTIONS"
    echo "=================================================="
    echo
    echo "🌐 Web Interfaces:"
    echo "   • OpenFGA API: http://localhost:8080"
    echo "   • Banking App: http://localhost:3001"
    echo "   • GenAI RAG Agent: http://localhost:8001"
    echo "   • GenAI API Docs: http://localhost:8001/docs"
    echo
    echo "🔍 API Health Checks:"
    echo "   curl http://localhost:8080/healthz"
    echo "   curl http://localhost:3001/health"
    echo "   curl http://localhost:8001/health"
    echo
    echo "=================================================="
    echo "            DEMO USAGE EXAMPLES"
    echo "=================================================="
    echo
    echo "Banking App API Examples:"
    echo "   # List accounts"
    echo "   curl -H 'x-user-id: alice' http://localhost:3001/api/accounts"
    echo
    echo "   # Get user info"
    echo "   curl -H 'x-user-id: alice' http://localhost:3001/api/users/me"
    echo
    echo "   # Create transaction"
    echo "   curl -X POST http://localhost:3001/api/transactions \\"
    echo "     -H 'x-user-id: alice' \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"from\": \"acc_001\", \"to\": \"acc_002\", \"amount\": 100}'"
    echo
    echo "GenAI RAG API Examples:"
    echo "   # Get user info"
    echo "   curl -H 'x-user-id: alice' http://localhost:8001/api/users/me"
    echo
    echo "   # List knowledge bases"
    echo "   curl -H 'x-user-id: alice' http://localhost:8001/api/knowledge-bases"
    echo
    echo "   # Create chat session"
    echo "   curl -X POST http://localhost:8001/api/chat/sessions \\"
    echo "     -H 'x-user-id: alice' \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"name\": \"Demo Chat\", \"organization_id\": \"demo-org\", \"knowledge_base_ids\": [\"kb_demo\"], \"model_id\": \"gpt-3.5-turbo\"}'"
    echo
    echo "=================================================="
    echo "            MANAGEMENT COMMANDS"
    echo "=================================================="
    echo
    echo "View logs:"
    echo "   $COMPOSE_CMD --env-file $ENV_FILE logs -f"
    echo "   $COMPOSE_CMD --env-file $ENV_FILE logs banking-app"
    echo "   $COMPOSE_CMD --env-file $ENV_FILE logs genai-rag-agent"
    echo
    echo "Restart services:"
    echo "   $COMPOSE_CMD --env-file $ENV_FILE restart"
    echo
    echo "Stop services:"
    echo "   $COMPOSE_CMD --env-file $ENV_FILE down"
    echo
    echo "Rebuild and restart:"
    echo "   $COMPOSE_CMD --env-file $ENV_FILE down"
    echo "   $COMPOSE_CMD --env-file $ENV_FILE build --no-cache"
    echo "   $COMPOSE_CMD --env-file $ENV_FILE up -d"
    echo
    echo "=================================================="
    echo "            TROUBLESHOOTING"
    echo "=================================================="
    echo
    echo "If services are not working:"
    echo "1. Check logs: $COMPOSE_CMD --env-file $ENV_FILE logs"
    echo "2. Verify Docker: docker info"
    echo "3. Check ports: netstat -an | grep ':8080\\|:3001\\|:8001'"
    echo "4. Restart: $COMPOSE_CMD --env-file $ENV_FILE restart"
    echo "5. Clean rebuild: $COMPOSE_CMD --env-file $ENV_FILE down && $COMPOSE_CMD --env-file $ENV_FILE build --no-cache && $COMPOSE_CMD --env-file $ENV_FILE up -d"
    echo
}

# Stop services
stop_services() {
    log_info "Stopping demo services..."
    
    cd "$PROJECT_ROOT"
    $COMPOSE_CMD --env-file "$ENV_FILE" down
    
    log_success "Services stopped"
}

# Clean up everything
cleanup_all() {
    log_info "Cleaning up all demo resources..."
    
    cd "$PROJECT_ROOT"
    $COMPOSE_CMD --env-file "$ENV_FILE" down --volumes --rmi all
    
    # Remove environment file
    if [[ -f "$ENV_FILE" ]]; then
        rm -f "$ENV_FILE" "$ENV_FILE.bak"
        log_info "Environment file removed"
    fi
    
    log_success "Cleanup completed"
}

# Handle cleanup on script exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Deployment failed. Check the logs above for details."
        echo
        echo "Common issues and solutions:"
        echo "1. Docker not running: Start Docker Desktop or Docker daemon"
        echo "2. Port conflicts: Stop other services using ports 8080, 3001, 8001"
        echo "3. Build failures: Check Dockerfiles and dependencies"
        echo "4. Network issues: Check Docker network settings"
        echo
        echo "Get detailed logs:"
        echo "  $COMPOSE_CMD --env-file $ENV_FILE logs"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Main function
main() {
    local action="deploy"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            start|deploy)
                action="deploy"
                shift
                ;;
            stop)
                action="stop"
                shift
                ;;
            status)
                action="status"
                shift
                ;;
            logs)
                action="logs"
                shift
                ;;
            restart)
                action="restart"
                shift
                ;;
            cleanup)
                action="cleanup"
                shift
                ;;
            --skip-setup)
                skip_setup=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [ACTION] [OPTIONS]"
                echo
                echo "Deploy OpenFGA Operator demo applications using Docker Compose"
                echo
                echo "Actions:"
                echo "  start, deploy  Deploy and start all services (default)"
                echo "  stop           Stop all services"
                echo "  status         Show service status"
                echo "  logs           Show service logs"
                echo "  restart        Restart all services"
                echo "  cleanup        Stop services and remove all resources"
                echo
                echo "Options:"
                echo "  --skip-setup   Skip demo data setup"
                echo "  -h, --help     Show this help message"
                echo
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
    done
    
    echo "=================================================="
    echo "  OpenFGA Demo Applications - Docker Compose"
    echo "=================================================="
    echo
    
    case $action in
        deploy)
            check_prerequisites
            create_env_file
            start_services
            wait_for_services
            if [[ "${skip_setup:-false}" != true ]]; then
                setup_demo_data
            fi
            show_status
            print_access_instructions
            ;;
        stop)
            check_prerequisites
            stop_services
            ;;
        status)
            show_status
            ;;
        logs)
            check_prerequisites
            cd "$PROJECT_ROOT"
            $COMPOSE_CMD --env-file "$ENV_FILE" logs -f
            ;;
        restart)
            check_prerequisites
            cd "$PROJECT_ROOT"
            $COMPOSE_CMD --env-file "$ENV_FILE" restart
            log_success "Services restarted"
            ;;
        cleanup)
            check_prerequisites
            cleanup_all
            ;;
    esac
}

# Execute main function with all arguments
main "$@"