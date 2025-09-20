#!/bin/bash

# Vault Secret Management Script for OpenFGA
# This script provides easy commands to manage secrets in Vault

set -e

VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
NAMESPACE="${NAMESPACE:-openfga-system}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo -e "${BLUE}Vault Secret Management for OpenFGA${NC}"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init               Initialize Vault with demo secrets"
    echo "  get-postgres       Get PostgreSQL credentials"
    echo "  set-postgres       Set PostgreSQL credentials"
    echo "  get-openfga        Get OpenFGA application secrets"
    echo "  set-openfga        Set OpenFGA application secrets"
    echo "  rotate-postgres    Rotate PostgreSQL password"
    echo "  list               List all secrets"
    echo "  status             Check Vault status"
    echo "  help               Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  VAULT_ADDR         Vault address (default: http://localhost:8200)"
    echo "  VAULT_TOKEN        Vault token (default: root)"
    echo "  NAMESPACE          Kubernetes namespace (default: openfga-system)"
    echo ""
    echo "Examples:"
    echo "  $0 init"
    echo "  $0 get-postgres"
    echo "  $0 set-postgres --username newuser --password newpass"
    echo "  $0 rotate-postgres"
    echo "  $0 list"
}

check_vault() {
    if ! command -v vault &> /dev/null; then
        echo -e "${RED}❌ Vault CLI not found. Please install HashiCorp Vault CLI${NC}"
        exit 1
    fi

    export VAULT_TOKEN="$VAULT_TOKEN"
    export VAULT_ADDR="$VAULT_ADDR"

    if ! vault status > /dev/null 2>&1; then
        echo -e "${RED}❌ Cannot connect to Vault at $VAULT_ADDR${NC}"
        echo "Make sure Vault is running and accessible:"
        echo "  kubectl port-forward -n $NAMESPACE svc/vault 8200:8200"
        exit 1
    fi
}

init_vault() {
    echo -e "${BLUE}🔐 Initializing Vault with demo secrets...${NC}"
    ./scripts/init-vault.sh
}

get_postgres() {
    echo -e "${BLUE}📋 PostgreSQL Credentials:${NC}"
    vault kv get -format=table secret/databases/openfga-postgres
}

set_postgres() {
    local username=""
    local password=""
    local database="openfga"
    local host="postgresql-openfga-vault"
    local port="5432"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --username)
                username="$2"
                shift 2
                ;;
            --password)
                password="$2"
                shift 2
                ;;
            --database)
                database="$2"
                shift 2
                ;;
            --host)
                host="$2"
                shift 2
                ;;
            --port)
                port="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done

    if [[ -z "$username" || -z "$password" ]]; then
        echo -e "${RED}❌ Username and password are required${NC}"
        echo "Usage: $0 set-postgres --username <user> --password <pass> [--database <db>] [--host <host>] [--port <port>]"
        exit 1
    fi

    echo -e "${YELLOW}⚠️  Setting PostgreSQL credentials...${NC}"
    vault kv put secret/databases/openfga-postgres \
        username="$username" \
        password="$password" \
        database="$database" \
        host="$host" \
        port="$port"
    
    echo -e "${GREEN}✅ PostgreSQL credentials updated${NC}"
}

get_openfga() {
    echo -e "${BLUE}📋 OpenFGA Application Secrets:${NC}"
    vault kv get -format=table secret/applications/openfga
}

set_openfga() {
    local jwt_secret=""
    local encryption_key=""
    local api_token=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --jwt-secret)
                jwt_secret="$2"
                shift 2
                ;;
            --encryption-key)
                encryption_key="$2"
                shift 2
                ;;
            --api-token)
                api_token="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done

    if [[ -z "$jwt_secret" || -z "$encryption_key" || -z "$api_token" ]]; then
        echo -e "${RED}❌ All secrets are required${NC}"
        echo "Usage: $0 set-openfga --jwt-secret <secret> --encryption-key <key> --api-token <token>"
        exit 1
    fi

    echo -e "${YELLOW}⚠️  Setting OpenFGA application secrets...${NC}"
    vault kv put secret/applications/openfga \
        jwt_secret="$jwt_secret" \
        encryption_key="$encryption_key" \
        api_token="$api_token"
    
    echo -e "${GREEN}✅ OpenFGA application secrets updated${NC}"
}

rotate_postgres() {
    echo -e "${YELLOW}🔄 Rotating PostgreSQL password...${NC}"
    
    # Generate new password
    local new_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    # Get current values
    local current_data=$(vault kv get -format=json secret/databases/openfga-postgres)
    local username=$(echo "$current_data" | jq -r '.data.data.username')
    local database=$(echo "$current_data" | jq -r '.data.data.database')
    local host=$(echo "$current_data" | jq -r '.data.data.host')
    local port=$(echo "$current_data" | jq -r '.data.data.port')
    
    # Update secret with new password
    vault kv put secret/databases/openfga-postgres \
        username="$username" \
        password="$new_password" \
        database="$database" \
        host="$host" \
        port="$port"
    
    echo -e "${GREEN}✅ PostgreSQL password rotated${NC}"
    echo -e "${BLUE}New password: $new_password${NC}"
    echo -e "${YELLOW}⚠️  PostgreSQL pods will restart automatically via VSO${NC}"
}

list_secrets() {
    echo -e "${BLUE}📋 All Secrets in Vault:${NC}"
    echo ""
    echo -e "${GREEN}PostgreSQL Secrets:${NC}"
    vault kv get -format=table secret/databases/openfga-postgres || echo "No PostgreSQL secrets found"
    echo ""
    echo -e "${GREEN}OpenFGA Application Secrets:${NC}"
    vault kv get -format=table secret/applications/openfga || echo "No OpenFGA secrets found"
}

vault_status() {
    echo -e "${BLUE}🔍 Vault Status:${NC}"
    vault status
    echo ""
    echo -e "${BLUE}🔍 Kubernetes Status:${NC}"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault
    echo ""
    kubectl get vaultauth,vaultconnection,vaultstaticsecret -n "$NAMESPACE" 2>/dev/null || echo "VSO resources not found"
}

# Main script
case "$1" in
    "init")
        check_vault
        init_vault
        ;;
    "get-postgres")
        check_vault
        get_postgres
        ;;
    "set-postgres")
        check_vault
        shift
        set_postgres "$@"
        ;;
    "get-openfga")
        check_vault
        get_openfga
        ;;
    "set-openfga")
        check_vault
        shift
        set_openfga "$@"
        ;;
    "rotate-postgres")
        check_vault
        rotate_postgres
        ;;
    "list")
        check_vault
        list_secrets
        ;;
    "status")
        check_vault
        vault_status
        ;;
    "help"|"--help"|"-h")
        usage
        ;;
    "")
        usage
        exit 1
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        usage
        exit 1
        ;;
esac