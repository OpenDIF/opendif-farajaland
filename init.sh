#!/bin/bash

# Master script to run both NDX infrastructure and member services
# Usage: ./init.sh

set -e

echo "=== Starting script at $(date) ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NDX_DIR="${SCRIPT_DIR}/ndx"
MEMBERS_DIR="${SCRIPT_DIR}/members"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to log errors with context
log_error() {
    local line_number=$1
    local command=$2
    local exit_code=$3
    print_error "Command failed at line $line_number with exit code $exit_code"
    print_error "Failed command: $command"
    echo "=== Error occurred at $(date) ===" >> "$LOG_FILE"
}

# Function to cleanup on exit
cleanup() {
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        print_error "Script failed with exit code: $exit_code"
    fi

    print_info "Stopping all services..."

    # Stop member services (they should be killed by the script itself)
    print_info "Member services stopping..."

    # Stop docker-compose services
    print_info "Stopping NDX infrastructure services..."
    cd "$NDX_DIR" && docker-compose down

    print_success "All services stopped"
    exit $exit_code
}

# Set trap to cleanup on exit and capture errors
trap cleanup INT TERM EXIT
trap 'log_error ${LINENO} "$BASH_COMMAND" $?' ERR

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

print_info "Starting OpenDIF Farajaland - All Services"
print_info "==========================================="
echo ""

# Start NDX infrastructure services
print_info "Starting NDX infrastructure services (docker-compose)..."
cd "$NDX_DIR"

if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml not found in ndx directory"
    exit 1
fi

# Start docker-compose in detached mode
docker-compose up -d

if [ $? -ne 0 ]; then
    print_error "Failed to start docker-compose services"
    exit 1
fi

print_success "NDX infrastructure services started"
echo ""
print_info "Running services:"
print_info "  - etcd (ports 2379, 2380)"
print_info "  - API Gateway (ports 9080, 9180)"
print_info "  - Policy Decision Point (port 8082)"
print_info "  - Consent Engine (port 8081)"
print_info "  - Orchestration Engine (port 4000)"
print_info "  - PostgreSQL (port 5432)"
echo ""

# Wait for infrastructure services to be ready
print_info "Waiting for infrastructure services to be ready..."
sleep 30

# Check if postgres is ready
print_info "Checking PostgreSQL health..."
for i in {1..30}; do
    if docker-compose exec -T postgres pg_isready -U exchange > /dev/null 2>&1; then
        print_success "PostgreSQL is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        print_warning "PostgreSQL health check timeout, continuing anyway..."
    fi
    sleep 1
done

print_info "Checking WSO2 Identity Server health..."

for i in $(seq 1 30); do
    STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}" --insecure \
        https://localhost:9443/console)

    if [ "$STATUS_CODE" = "200" ] || [ "$STATUS_CODE" = "302" ]; then
        print_success "WSO2 Identity Server is ready"
        break
    fi

    if [ "$i" -eq 30 ]; then
        print_warning "WSO2 Identity Server health check timeout, continuing anyway..."
    fi

    sleep 2
done

# Step 1: Create initial DCR application to obtain credentials for Management API access
print_info "Creating temporary DCR application for Management API access..."
DCR_RESPONSE=$(curl --silent -X POST https://localhost:9443/api/identity/oauth2/dcr/v1.1/register \
  --insecure \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic YWRtaW46YWRtaW4=" \
  -d '{
    "client_name": "TEMPORARY_DCR_APP",
    "grant_types": ["client_credentials"],
    "token_type": "OAUTH",
    "scope": "internal_application_mgt_view internal_application_mgt_create internal_application_mgt_update internal_application_mgt_delete"
  }')

CURL_EXIT_CODE=$?

if [ $CURL_EXIT_CODE -ne 0 ]; then
    print_error "Failed to create temporary DCR application (curl exit code: $CURL_EXIT_CODE)"
    exit 1
fi

DCR_CLIENT_ID=$(echo "$DCR_RESPONSE" | jq -r '.client_id')
DCR_CLIENT_SECRET=$(echo "$DCR_RESPONSE" | jq -r '.client_secret')

if [ "$DCR_CLIENT_ID" = "null" ] || [ -z "$DCR_CLIENT_ID" ]; then
    print_error "Failed to extract Client ID from DCR response"
    print_error "Response was: $DCR_RESPONSE"
    exit 1
fi

print_success "Temporary DCR application created successfully!"
print_info "Temporary Client ID: $DCR_CLIENT_ID"
print_info "Temporary Client Secret: $DCR_CLIENT_SECRET"
echo ""

# Step 2: Obtain access token using DCR credentials
print_info "Obtaining access token for Management API..."
print_info "Requesting scopes: internal_application_mgt_view internal_application_mgt_create internal_application_mgt_update internal_application_mgt_delete"

TOKEN_RESPONSE=$(curl --silent -X POST https://localhost:9443/oauth2/token \
  --insecure \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "$DCR_CLIENT_ID:$DCR_CLIENT_SECRET" \
  -d "grant_type=client_credentials&scope=internal_application_mgt_view internal_application_mgt_create internal_application_mgt_update internal_application_mgt_delete")

print_info "Token Response: $TOKEN_RESPONSE"

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    print_error "Failed to obtain access token"
    print_error "Response was: $TOKEN_RESPONSE"
    print_warning "The temporary DCR application may not have the necessary permissions."
    print_warning "Falling back to using admin credentials directly for application creation..."

    # Fallback: Use DCR directly for both applications
    print_info "Creating M2M application for API Gateway using DCR..."
    GATEWAY_DCR_RESPONSE=$(curl --silent -X POST https://localhost:9443/api/identity/oauth2/dcr/v1.1/register \
      --insecure \
      -H "Content-Type: application/json" \
      -H "Authorization: Basic YWRtaW46YWRtaW4=" \
      -d '{
        "client_name": "NDX_API_GATEWAY",
        "grant_types": ["client_credentials", "refresh_token"],
        "token_type": "OAUTH"
      }')

    CLIENT_ID=$(echo "$GATEWAY_DCR_RESPONSE" | jq -r '.client_id')
    CLIENT_SECRET=$(echo "$GATEWAY_DCR_RESPONSE" | jq -r '.client_secret')

    if [ "$CLIENT_ID" = "null" ] || [ -z "$CLIENT_ID" ]; then
        print_error "Failed to create API Gateway application"
        exit 1
    fi

    print_success "API Gateway application created successfully!"
    print_info "API Gateway Client ID: $CLIENT_ID"

    # Skip to Consent Portal creation (will be handled later in script)
    USE_MANAGEMENT_API=false
else
    print_success "Access token obtained successfully!"
    print_info "Access Token (first 20 chars): ${ACCESS_TOKEN:0:20}..."
    echo ""
    USE_MANAGEMENT_API=true

    # Step 3: Create M2M application for API Gateway using Management API
    print_info "Creating M2M application for API Gateway using Management API..."
    GATEWAY_APP_RESPONSE=$(curl --silent -w "\nHTTP_STATUS:%{http_code}" -X POST https://localhost:9443/api/server/v1/applications \
      --insecure \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -d '{
        "name": "NDX_API_GATEWAY",
        "description": "Machine-to-Machine application for NDX API Gateway",
        "inboundProtocolConfiguration": {
          "oidc": {
            "grantTypes": ["client_credentials", "refresh_token"],
            "publicClient": false
          }
        }
      }')

    HTTP_STATUS=$(echo "$GATEWAY_APP_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    GATEWAY_APP_BODY=$(echo "$GATEWAY_APP_RESPONSE" | sed '/HTTP_STATUS:/d')

    print_info "HTTP Status: $HTTP_STATUS"
    print_info "Response Body: $GATEWAY_APP_BODY"

    if [ "$HTTP_STATUS" != "201" ]; then
        print_error "Failed to create API Gateway application via Management API (HTTP $HTTP_STATUS)"
        print_error "Response: $GATEWAY_APP_BODY"
        print_warning "Falling back to DCR for application creation..."

        GATEWAY_DCR_RESPONSE=$(curl --silent -X POST https://localhost:9443/api/identity/oauth2/dcr/v1.1/register \
          --insecure \
          -H "Content-Type: application/json" \
          -H "Authorization: Basic YWRtaW46YWRtaW4=" \
          -d '{
            "client_name": "NDX_API_GATEWAY",
            "grant_types": ["client_credentials", "refresh_token"],
            "token_type": "OAUTH"
          }')

        CLIENT_ID=$(echo "$GATEWAY_DCR_RESPONSE" | jq -r '.client_id')
        CLIENT_SECRET=$(echo "$GATEWAY_DCR_RESPONSE" | jq -r '.client_secret')
        USE_MANAGEMENT_API=false
    else
        GATEWAY_APP_ID=$(echo "$GATEWAY_APP_BODY" | jq -r '.id')

        if [ "$GATEWAY_APP_ID" = "null" ] || [ -z "$GATEWAY_APP_ID" ]; then
            print_error "Failed to extract application ID"
            exit 1
        fi

        print_success "API Gateway application created successfully!"
        print_info "Application ID: $GATEWAY_APP_ID"
        echo ""

        # Get the OAuth credentials for the Gateway app
        print_info "Retrieving OAuth credentials for API Gateway application..."
        GATEWAY_INBOUND_RESPONSE=$(curl --silent -X GET "https://localhost:9443/api/server/v1/applications/$GATEWAY_APP_ID/inbound-protocols/oidc" \
          --insecure \
          -H "Authorization: Bearer $ACCESS_TOKEN")

        CLIENT_ID=$(echo "$GATEWAY_INBOUND_RESPONSE" | jq -r '.clientId')
        CLIENT_SECRET=$(echo "$GATEWAY_INBOUND_RESPONSE" | jq -r '.clientSecret')

        if [ "$CLIENT_ID" = "null" ] || [ -z "$CLIENT_ID" ]; then
            print_error "Failed to retrieve API Gateway OAuth credentials"
            print_error "Response was: $GATEWAY_INBOUND_RESPONSE"
            exit 1
        fi

        print_success "API Gateway OAuth credentials retrieved successfully!"
        print_info "API Gateway Client ID: $CLIENT_ID"
    fi
fi

echo ""


# Register Orchestration Engine Routes
print_info "Exposing OE Endpoints Publicly with OpenID Connect Authentication"
curl --location --request PUT http://localhost:9180/apisix/admin/routes \
  --header "Content-Type: application/json" \
  --header "X-API-KEY: QuNGwapKysRvHfUtNkQFbUaGiiYeOcGo" \
  --data @- <<EOF
  {
    "uri": "/public/*",
    "methods": ["GET", "POST"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "orchestration-engine:4000": 1
      }
    },
    "plugins": {
      "openid-connect": {
        "discovery": "https://wso2is:9443/oauth2/token/.well-known/openid-configuration",
        "bearer_only": true,
        "token_signing_alg_values_expected": "RS256",
        "set_userinfo_header": true,
        "client_id": "$CLIENT_ID",
        "client_secret": "$CLIENT_SECRET",
        "use_jwks": true,
        "ssl_verify": false
      }
    },
    "id": "oe-endpoint"
  }
EOF

if [ $? -ne 0 ]; then
    print_error "Failed to register OE public routes"
    exit 1
fi

print_info "Exposing Required Consent Engine Endpoints Publicly with OpenID Connect Authentication"

curl --location --request PUT 'http://localhost:9180/apisix/admin/routes' \
--header 'Content-Type: application/json' \
--header 'X-API-KEY: QuNGwapKysRvHfUtNkQFbUaGiiYeOcGo' \
--data @- <<EOF
{
    "uri": "/consents/*",
    "methods": [
        "GET",
        "PUT",
        "OPTIONS"
    ],
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "consent-engine:8081": 1
        }
    },
    "plugins": {
        "openid-connect": {
            "discovery": "https://wso2is:9443/oauth2/token/.well-known/openid-configuration",
            "bearer_only": true,
            "token_signing_alg_values_expected": "RS256",
            "set_userinfo_header": true,
            "client_id": "$CLIENT_ID",
            "client_secret": "$CLIENT_SECRET",
            "use_jwks": true,
            "ssl_verify": false
        },
        "cors": {
            "allow_origins": "http://localhost:5173",
            "allow_headers": "*",
            "allow_methods": "*"
        }
    },
    "id": "consent-endpoint"
}
EOF


if [ $? -ne 0 ]; then
    print_error "Failed to register consent engine routes"
    exit 1
fi

print_success "Consent engine routes registered successfully"
echo ""

# Step 4: Create SPA application for Consent Portal
if [ "$USE_MANAGEMENT_API" = true ]; then
    print_info "Creating SPA application for Consent Portal using Management API..."
    PORTAL_APP_RESPONSE=$(curl --silent -w "\nHTTP_STATUS:%{http_code}" -X POST https://localhost:9443/api/server/v1/applications \
      --insecure \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -d '{
        "name": "NDX_CONSENT_PORTAL",
        "description": "Single-Page Application for NDX Consent Portal",
        "inboundProtocolConfiguration": {
          "oidc": {
            "grantTypes": ["authorization_code", "refresh_token"],
            "callbackURLs": ["http://localhost:5173"],
            "allowedOrigins": ["http://localhost:5173"],
            "publicClient": true,
            "pkce": {
              "mandatory": true,
              "supportPlainTransformAlgorithm": false
            },
            "accessToken": {
              "type": "Default",
              "applicationAccessTokenExpiryInSeconds": 3600,
              "userAccessTokenExpiryInSeconds": 3600
            },
            "refreshToken": {
              "expiryInSeconds": 86400,
              "renewRefreshToken": true
            },
            "idToken": {
              "expiryInSeconds": 3600
            }
          }
        }
      }')

    HTTP_STATUS=$(echo "$PORTAL_APP_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    PORTAL_APP_BODY=$(echo "$PORTAL_APP_RESPONSE" | sed '/HTTP_STATUS:/d')

    print_info "HTTP Status: $HTTP_STATUS"
    print_info "Response Body: $PORTAL_APP_BODY"

    if [ "$HTTP_STATUS" != "201" ]; then
        print_error "Failed to create Consent Portal application via Management API (HTTP $HTTP_STATUS)"
        print_error "Response: $PORTAL_APP_BODY"
        print_warning "Falling back to DCR for Consent Portal creation..."
        USE_MANAGEMENT_API=false
    else
        PORTAL_APP_ID=$(echo "$PORTAL_APP_BODY" | jq -r '.id')

        if [ "$PORTAL_APP_ID" = "null" ] || [ -z "$PORTAL_APP_ID" ]; then
            print_error "Failed to extract Consent Portal application ID"
            exit 1
        fi

        print_success "Consent Portal application created successfully!"
        print_info "Application ID: $PORTAL_APP_ID"
        echo ""

        # Get the OAuth credentials for the Consent Portal app
        print_info "Retrieving OAuth credentials for Consent Portal application..."
        PORTAL_INBOUND_RESPONSE=$(curl --silent -X GET "https://localhost:9443/api/server/v1/applications/$PORTAL_APP_ID/inbound-protocols/oidc" \
          --insecure \
          -H "Authorization: Bearer $ACCESS_TOKEN")

        PORTAL_CLIENT_ID=$(echo "$PORTAL_INBOUND_RESPONSE" | jq -r '.clientId')

        if [ "$PORTAL_CLIENT_ID" = "null" ] || [ -z "$PORTAL_CLIENT_ID" ]; then
            print_error "Failed to retrieve Consent Portal OAuth credentials"
            print_error "Response was: $PORTAL_INBOUND_RESPONSE"
            exit 1
        fi

        print_success "Consent Portal OAuth credentials retrieved successfully!"
        print_info "Consent Portal Client ID: $PORTAL_CLIENT_ID"
    fi
fi

# Fallback to DCR if Management API approach failed or wasn't used
if [ "$USE_MANAGEMENT_API" != true ]; then
    print_info "Creating SPA application for Consent Portal using DCR..."
    PORTAL_DCR_RESPONSE=$(curl --silent -X POST https://localhost:9443/api/identity/oauth2/dcr/v1.1/register \
      --insecure \
      -H "Content-Type: application/json" \
      -H "Authorization: Basic YWRtaW46YWRtaW4=" \
      -d '{
        "client_name": "NDX_CONSENT_PORTAL",
        "redirect_uris": ["http://localhost:5173"],
        "grant_types": ["authorization_code", "refresh_token"],
        "ext_pkce_mandatory": true,
        "ext_pkce_support_plain": false,
        "ext_public_client": true,
        "ext_application_token_lifetime": 3600,
        "ext_user_token_lifetime": 3600,
        "ext_refresh_token_lifetime": 86400,
        "ext_id_token_lifetime": 3600,
        "token_type": "OAUTH"
      }')

    PORTAL_CLIENT_ID=$(echo "$PORTAL_DCR_RESPONSE" | jq -r '.client_id')

    if [ "$PORTAL_CLIENT_ID" = "null" ] || [ -z "$PORTAL_CLIENT_ID" ]; then
        print_error "Failed to create Consent Portal application"
        print_error "Response was: $PORTAL_DCR_RESPONSE"
        exit 1
    fi

    print_success "Consent Portal application created successfully!"
    print_info "Consent Portal Client ID: $PORTAL_CLIENT_ID"
    print_warning "CORS allowed origins not configured. Please configure manually in WSO2 IS console if needed."
fi

echo ""

# Note: Not deleting the temporary DCR application so it can be used for manual testing
if [ ! -z "$DCR_CLIENT_ID" ]; then
    print_warning "Temporary DCR application NOT deleted for manual testing:"
    print_info "  Client ID: $DCR_CLIENT_ID"
    print_info "  Client Secret: $DCR_CLIENT_SECRET"
    print_info "  You can use these credentials to test Management API calls via Postman"
    print_info "  To delete manually: DELETE https://localhost:9443/api/identity/oauth2/dcr/v1.1/register/$DCR_CLIENT_ID"
fi

echo ""
print_success "Application setup completed!"
print_info "API Gateway Client ID: $CLIENT_ID"
print_info "Consent Portal Client ID: $PORTAL_CLIENT_ID"
echo ""

# Start member services
print_info "Starting member data source services..."
cd "$MEMBERS_DIR"

if [ ! -f "run-services-v2.sh" ]; then
    print_error "run-services.sh not found in members directory"
    exit 1
fi

if [ ! -x "run-services-v2.sh" ]; then
    print_info "Making run-services.sh executable..."
    chmod +x run-services-v2.sh
fi

# Run member services
./run-services-v2.sh all

print_success "=========================================="
print_success "All services started successfully!"
print_success "=========================================="
echo ""
print_warning "Press Ctrl+C to stop all services"
echo ""

# Keep script running until interrupted
print_info "All services are running. Monitoring..."
while true; do
    sleep 60
done