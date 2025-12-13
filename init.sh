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
sleep 20

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
    # Use curl with error handling - don't exit on failure
    if STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 5 --max-time 10 --insecure \
        https://wso2is:9443/console 2>/dev/null); then

        if [ "$STATUS_CODE" = "200" ] || [ "$STATUS_CODE" = "302" ]; then
            print_success "WSO2 Identity Server is ready (HTTP $STATUS_CODE)"
            break
        else
            print_info "WSO2 IS responded with HTTP $STATUS_CODE, retrying... ($i/30)"
        fi
    else
        print_info "WSO2 IS not reachable yet, retrying... ($i/30)"
    fi

    if [ "$i" -eq 30 ]; then
        print_error "WSO2 Identity Server health check failed after 30 attempts"
        print_error "Please check if WSO2 IS container is running properly:"
        print_error "  docker-compose -f $NDX_DIR/docker-compose.yml logs wso2is"
        print_error ""
        print_error "The script will now exit. Please resolve the issue and try again."
        exit 1
    fi

    sleep 2
done

# Step 1: Create initial DCR application to obtain credentials for Management API access
print_info "Creating temporary DCR application for Management API access..."
DCR_RESPONSE=$(curl --silent -X POST https://wso2is:9443/api/identity/oauth2/dcr/v1.1/register \
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

# Step 2: Create API Gateway application using DCR endpoint
print_info "Creating M2M application for API Gateway using DCR endpoint..."
GATEWAY_DCR_RESPONSE=$(curl --silent -X POST https://wso2is:9443/api/identity/oauth2/dcr/v1.1/register \
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
    print_error "Failed to create API Gateway application via DCR"
    print_error "Response was: $GATEWAY_DCR_RESPONSE"
    exit 1
fi

print_success "API Gateway application created successfully via DCR!"
print_info "API Gateway Client ID: $CLIENT_ID"
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
            "ssl_verify": false,
            "access_token_in_authorization_header": true
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

# Step 4: Grant permissions to the temporary DCR application
echo ""
print_warning "=========================================="
print_warning "MANUAL STEP REQUIRED: Grant Application Management Permissions"
print_warning "=========================================="
echo ""
print_info "To allow automated creation of the Consent Portal SPA application,"
print_info "please grant the necessary permissions to the temporary DCR application."
echo ""
print_info "Follow these steps:"
echo ""
print_info "1. Open WSO2 Identity Server Console: https://wso2is:9443/console"
print_info "2. Login with credentials: admin / admin"
print_info "3. Navigate to: Applications"
print_info "4. Find and click on the application: TEMPORARY_DCR_APP"
print_info "5. Go to the 'API Authorization' tab"
print_info "6. Click 'Authorize an API Resource'"
print_info "7. Select: Application Management API"
print_info "8. Grant the following scopes:"
print_info "   - internal_application_mgt_view"
print_info "   - internal_application_mgt_create"
print_info "   - internal_application_mgt_update"
print_info "9. Click 'Finish' to save the permissions"
echo ""
print_warning "After granting permissions, the script will automatically create the Consent Portal application."
echo ""

# Prompt user to confirm they have granted permissions
while true; do
    printf "%b" "${BLUE}[CONFIRM]${NC} Have you granted the required permissions? (y/n): "
    read PERMISSIONS_GRANTED

    if [[ "$PERMISSIONS_GRANTED" =~ ^[Yy]$ ]]; then
        print_success "Permissions confirmed. Proceeding with application creation..."
        break
    elif [[ "$PERMISSIONS_GRANTED" =~ ^[Nn]$ ]]; then
        print_warning "Please grant the permissions before continuing."
    else
        print_error "Invalid input. Please enter 'y' or 'n'."
    fi
done

# First, obtain a new access token with the updated permissions
TOKEN_RESPONSE=$(curl --silent -X POST https://wso2is:9443/oauth2/token \
  --insecure \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "$DCR_CLIENT_ID:$DCR_CLIENT_SECRET" \
  -d "grant_type=client_credentials&scope=internal_application_mgt_view internal_application_mgt_create internal_application_mgt_update internal_application_mgt_client_secret_view")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    print_error "Failed to obtain access token with updated permissions"
    print_error "Response was: $TOKEN_RESPONSE"
    exit 1
fi

print_success "Access token obtained successfully!"
echo ""

# Create M2M Application using Management API
print_info "Creating M2M application (Passport Application) using Management API..."

M2M_APP_RESPONSE=$(curl --silent --insecure -i \
  -X POST https://wso2is:9443/api/server/v1/applications \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d @- <<EOF
{
  "name": "Passport Application",
  "templateId": "m2m-application",
  "associatedRoles": {
    "allowedAudience": "APPLICATION",
    "roles": []
  },
  "inboundProtocolConfiguration": {
    "oidc": {
      "grantTypes": ["client_credentials"],
      "accessToken": {
        "accessTokenAttributes": [],
        "applicationAccessTokenExpiryInSeconds": 3600,
        "revokeTokensWhenIDPSessionTerminated": false,
        "type": "JWT",
        "userAccessTokenExpiryInSeconds": 0,
        "validateTokenBinding": false
      }
    }
  }
}
EOF
)

M2M_HTTP_STATUS=$(echo "$M2M_APP_RESPONSE" | grep "HTTP/" | head -1 | awk '{print $2}')
M2M_LOCATION=$(echo "$M2M_APP_RESPONSE" | grep -i "^location:" | cut -d: -f2- | tr -d '\r' | xargs)
M2M_APP_BODY=$(echo "$M2M_APP_RESPONSE" | sed -n '/^{/,/^}/p')

if [ "$M2M_HTTP_STATUS" != "201" ]; then
    print_error "Failed to create M2M application via Management API (HTTP $M2M_HTTP_STATUS)"
    print_error "Response: $M2M_APP_BODY"
    exit 1
fi

# Extract application ID from Location header
# Location format: https://wso2is:9443/api/server/v1/applications/{app-id}
M2M_APP_ID=$(echo "$M2M_LOCATION" | sed 's|.*/applications/||')

if [ -z "$M2M_APP_ID" ]; then
    print_error "Failed to extract application ID from Location header"
    print_error "Location header was: $M2M_LOCATION"
    exit 1
fi

# Retrieve the full application details to get client ID and secret
print_info "Retrieving M2M application credentials..."
M2M_DETAILS_RESPONSE=$(curl --silent -w "\nHTTP_STATUS:%{http_code}" -X GET "https://wso2is:9443/api/server/v1/applications/$M2M_APP_ID/inbound-protocols/oidc" \
  --insecure \
  -H "Authorization: Bearer $ACCESS_TOKEN")

M2M_DETAILS_HTTP_STATUS=$(echo "$M2M_DETAILS_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
M2M_DETAILS_BODY=$(echo "$M2M_DETAILS_RESPONSE" | sed '/HTTP_STATUS:/d')

# Print the body for debugging
print_info "M2M Application Details Response (HTTP $M2M_DETAILS_HTTP_STATUS):"
echo "$M2M_DETAILS_BODY"

if [ "$M2M_DETAILS_HTTP_STATUS" != "200" ]; then
    print_error "Failed to retrieve M2M application details (HTTP $M2M_DETAILS_HTTP_STATUS)"
    print_error "Response: $M2M_DETAILS_BODY"
    exit 1
fi

M2M_CLIENT_ID=$(echo "$M2M_DETAILS_BODY" | jq -r '.clientId')
M2M_CLIENT_SECRET=$(echo "$M2M_DETAILS_BODY" | jq -r '.clientSecret')

if [ "$M2M_CLIENT_ID" = "null" ] || [ -z "$M2M_CLIENT_ID" ]; then
    print_error "Failed to extract M2M Client ID from application details"
    print_error "Response: $M2M_DETAILS_BODY"
    exit 1
fi

print_success "M2M application (Passport Application) created successfully!"
echo ""
print_success "=========================================="
print_success "M2M Application Credentials"
print_success "=========================================="
print_info "Application Name: Passport Application"
print_info "Client ID:        $M2M_CLIENT_ID"
print_info "Client Secret:    $M2M_CLIENT_SECRET"
print_success "=========================================="
echo ""

# Define the Consent Portal client ID
PORTAL_CLIENT_ID="Mpjt5VUqDPL8iVByyFcMDregz6Ea"

# Now attempt to create the Consent Portal SPA application using the Management API
print_info "Creating SPA application for Consent Portal using Management API..."

# Create the Consent Portal SPA application with predefined client_id
print_info "Creating Consent Portal application with client ID: $PORTAL_CLIENT_ID"

PORTAL_APP_RESPONSE=$(curl --silent -w "\nHTTP_STATUS:%{http_code}" -X POST https://wso2is:9443/api/server/v1/applications \
  --insecure \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d @- <<EOF
{
  "name": "NDX_CONSENT_PORTAL",
  "templateId": "6a90e4b0-fbff-42d7-bfde-1efd98f07cd7",
  "description": "Single-Page Application for NDX Consent Portal",
  "inboundProtocolConfiguration": {
    "oidc": {
      "clientId": "$PORTAL_CLIENT_ID",
      "grantTypes": ["authorization_code", "refresh_token"],
      "callbackURLs": ["http://localhost:5173"],
      "allowedOrigins": ["http://localhost:5173"],
      "publicClient": true,
      "pkce": {
        "mandatory": true,
        "supportPlainTransformAlgorithm": false
      },
      "accessToken": {
        "type": "JWT",
        "userAccessTokenExpiryInSeconds": 3600,
        "applicationAccessTokenExpiryInSeconds": 3600,
        "accessTokenAttributes": [
          "email"
        ]
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
}
EOF
)

HTTP_STATUS=$(echo "$PORTAL_APP_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
PORTAL_APP_BODY=$(echo "$PORTAL_APP_RESPONSE" | sed '/HTTP_STATUS:/d')

print_info "Consent Portal Application Creation Response (HTTP $HTTP_STATUS):"
echo "$PORTAL_APP_BODY"

if [ "$HTTP_STATUS" != "201" ]; then
    print_error "Failed to create Consent Portal application via Management API (HTTP $HTTP_STATUS)"
    print_error "Response: $PORTAL_APP_BODY"
    exit 1
fi

print_success "Consent Portal application created successfully!"
print_info "Consent Portal Client ID: $PORTAL_CLIENT_ID"

echo ""

# Note: Not deleting the temporary DCR application so it can be used for manual testing
if [ ! -z "$DCR_CLIENT_ID" ]; then
    print_warning "Temporary DCR application NOT deleted for manual testing:"
    print_info "  Client ID: $DCR_CLIENT_ID"
    print_info "  Client Secret: $DCR_CLIENT_SECRET"
    print_info "  You can use these credentials to test Management API calls via Postman"
    print_info "  To delete manually: DELETE https://wso2is:9443/api/identity/oauth2/dcr/v1.1/register/$DCR_CLIENT_ID"
fi

echo ""
print_success "=========================================="
print_success "Application Setup Completed!"
print_success "=========================================="
echo ""
print_info "API Gateway Client ID: $CLIENT_ID"
print_info "Consent Portal Client ID: $PORTAL_CLIENT_ID"
echo ""

# Start member services
print_info "Starting member data source services..."
cd "$MEMBERS_DIR"

if [ ! -f "run-member-services.sh" ]; then
    print_error "run-services.sh not found in members directory"
    exit 1
fi

if [ ! -x "run-member-services.sh" ]; then
    print_info "Making run-member-services.sh executable..."
    chmod +x run-member-services.sh
fi

# Run member services
./run-member-services.sh all

echo ""
print_success "=========================================="
print_success "Passport Application (M2M) Credentials"
print_success "=========================================="
print_info "Use these credentials to call the API:"
echo ""
print_info "Client ID:     $M2M_CLIENT_ID"
print_info "Client Secret: $M2M_CLIENT_SECRET"
print_success "=========================================="
echo ""
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