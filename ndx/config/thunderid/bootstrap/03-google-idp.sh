#!/bin/bash

set -e

# ============================================================================
# Bootstrap script: configure Google Federated Login & Claim Mapping.
#
# Runs inside the `thunderid-setup` container (mounted to
# /opt/thunderid/bootstrap/03-google-idp.sh), after 02-admin-cli.sh, with
# security disabled. It sources the image's common.sh for api_call / log_*.
# ============================================================================

# Source common functions from the same directory as this script
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]:-$0}")"
source "${SCRIPT_DIR}/common.sh"

# ============================================================================
# Helpers
# ============================================================================

extract_first_id() {
    echo "$1" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4
}

get_ou_id_by_handle() {
    local OU_HANDLE="$1"
    local RESPONSE HTTP_CODE BODY
    RESPONSE=$(api_call GET "/organization-units/tree/${OU_HANDLE}")
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"

    if [[ "$HTTP_CODE" != "200" ]]; then
        echo ""
        return
    fi

    extract_first_id "$BODY"
}

# ============================================================================
# 1. Update "Person" User Type Schema to include "opendif/userid" attribute
# ============================================================================

log_info "Retrieving Person user type ID..."
GET_RESPONSE=$(api_call GET "/user-types")
HTTP_CODE="${GET_RESPONSE: -3}"
BODY="${GET_RESPONSE%???}"

if [[ "$HTTP_CODE" != "200" ]]; then
    log_error "Failed to retrieve user types (HTTP $HTTP_CODE)"
    exit 1
fi

PERSON_TYPE_ID=$(echo "$BODY" | sed -E 's/\},[[:space:]]*\{/\}\n\{/g' | grep '"name":"Person"' | grep -o '"id":"[^"]*"' | head -n 1 | cut -d'"' -f4)

if [[ -z "$PERSON_TYPE_ID" ]]; then
    log_error "Person user type not found in types list"
    exit 1
fi

log_success "Found Person user type ID: $PERSON_TYPE_ID"

DEFAULT_OU_ID=$(get_ou_id_by_handle "default")
if [[ -z "$DEFAULT_OU_ID" ]]; then
    log_error "Default organization unit ID not found"
    exit 1
fi

log_info "Updating Person user type schema to include custom 'opendif/userid' attribute..."

read -r -d '' USER_TYPE_PAYLOAD <<JSON || true
{
  "name": "Person",
  "ouId": "${DEFAULT_OU_ID}",
  "allowSelfRegistration": false,
  "systemAttributes": {"display":"username"},
  "schema": {
    "username":{"type":"string","displayName":"Username","required":true,"unique":true},
    "email":{"type":"string","displayName":"Email","required":true,"unique":true,"regex":"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\\\.[a-zA-Z]{2,}$"},
    "given_name":{"type":"string","displayName":"First Name","required":false},
    "family_name":{"type":"string","displayName":"Last Name","required":false},
    "mobileNumber":{"type":"string","displayName":"Mobile Number","required":false},
    "phone_number":{"type":"string","displayName":"Phone Number","required":false},
    "sub":{"type":"string","displayName":"Subject","required":false},
    "name":{"type":"string","displayName":"Full Name","required":false},
    "picture":{"type":"string","displayName":"Picture","required":false},
    "password":{"type":"string","displayName":"Password","required":false,"credential":true},
    "opendif-uid":{"type":"string","displayName":"OpenDIF User ID","required":false}
  }
}
JSON

RESPONSE=$(api_call PUT "/user-types/${PERSON_TYPE_ID}" "${USER_TYPE_PAYLOAD}")
HTTP_CODE="${RESPONSE: -3}"
BODY="${RESPONSE%???}"

if [[ "$HTTP_CODE" == "200" ]]; then
    log_success "Person user type schema updated successfully"
else
    log_error "Failed to update Person user type schema (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
    exit 1
fi

# ============================================================================
# 2. Configure Google Federated Login Connection & Claim Mapping
# ============================================================================

log_info "Checking if Google Identity Provider already exists..."
GET_RESPONSE=$(api_call GET "/identity-providers")
HTTP_CODE="${GET_RESPONSE: -3}"
BODY="${GET_RESPONSE%???}"

if [[ "$HTTP_CODE" != "200" ]]; then
    log_error "Failed to retrieve identity providers (HTTP $HTTP_CODE)"
    exit 1
fi

if [[ -z "${GOOGLE_CLIENT_ID}" ]] || [[ -z "${GOOGLE_CLIENT_SECRET}" ]]; then
    log_error "GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET environment variables are required."
    log_error "Please set them in ndx/.env or export them before running this script."
    exit 1
fi

CLIENT_ID="${GOOGLE_CLIENT_ID}"
CLIENT_SECRET="${GOOGLE_CLIENT_SECRET}"
AUTH_EP="https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_EP="https://oauth2.googleapis.com/token"

log_info "Using Google OIDC endpoints: Auth -> ${AUTH_EP}, Token -> ${TOKEN_EP}"

read -r -d '' IDP_PAYLOAD <<JSON || true
{
  "name": "Google",
  "type": "OIDC",
  "properties": [
    { "name": "client_id", "value": "${CLIENT_ID}" },
    { "name": "client_secret", "value": "${CLIENT_SECRET}" },
    { "name": "redirect_uri", "value": "https://localhost:8090/commonauth" },
    { "name": "authorization_endpoint", "value": "${AUTH_EP}" },
    { "name": "token_endpoint", "value": "${TOKEN_EP}" },
    { "name": "issuer", "value": "https://accounts.google.com" }
  ],
  "attributeConfiguration": {
    "userTypeResolution": {
      "mode": "DEFAULT",
      "default": "Person"
    },
    "userTypeAttributeMappings": [
      {
        "userType": "Person",
        "attributes": [
          { "externalAttribute": "email", "localAttribute": "opendif-uid" }
        ]
      }
    ]
  }
}
JSON

if echo "$BODY" | grep -q '"name":"Google"'; then
    log_info "Google Identity Provider already exists, updating configuration..."
    IDP_ID=$(echo "$BODY" | sed -E 's/\},[[:space:]]*\{/\}\n\{/g' | grep '"name":"Google"' | grep -o '"id":"[^"]*"' | head -n 1 | cut -d'"' -f4)

    RESPONSE=$(api_call PUT "/identity-providers/${IDP_ID}" "${IDP_PAYLOAD}")
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"

    if [[ "$HTTP_CODE" == "200" ]]; then
        log_success "Google Identity Provider updated successfully"
    else
        log_error "Failed to update Google Identity Provider (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
        exit 1
    fi
else
    log_info "Creating Google Identity Provider connection with claim mapping..."

    RESPONSE=$(api_call POST "/identity-providers" "${IDP_PAYLOAD}")
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"

    if [[ "$HTTP_CODE" == "201" ]] || [[ "$HTTP_CODE" == "200" ]]; then
        log_success "Google Identity Provider created successfully"
    else
        log_error "Failed to create Google Identity Provider (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
        exit 1
    fi
fi

# ============================================================================
# 3. Update Default Basic Authentication Flow to Route Directly to Google
# ============================================================================

log_info "Resolving Google Identity Provider ID..."
GET_IDP_RESPONSE=$(api_call GET "/identity-providers")
IDP_HTTP_CODE="${GET_IDP_RESPONSE: -3}"
IDP_BODY="${GET_IDP_RESPONSE%???}"

if [[ "$IDP_HTTP_CODE" != "200" ]]; then
    log_error "Failed to retrieve identity providers to resolve ID (HTTP $IDP_HTTP_CODE)"
    exit 1
fi

GOOGLE_IDP_ID=$(echo "$IDP_BODY" | sed -E 's/\},[[:space:]]*\{/\}\n\{/g' | grep '"name":"Google"' | grep -o '"id":"[^"]*"' | head -n 1 | cut -d'"' -f4)

if [[ -z "$GOOGLE_IDP_ID" ]]; then
    log_error "Google Identity Provider ID not found"
    exit 1
fi

log_success "Resolved Google Identity Provider ID: $GOOGLE_IDP_ID"

log_info "Retrieving Default Basic Authentication Flow ID..."
GET_FLOWS_RESPONSE=$(api_call GET "/flows")
FLOWS_HTTP_CODE="${GET_FLOWS_RESPONSE: -3}"
FLOWS_BODY="${GET_FLOWS_RESPONSE%???}"

if [[ "$FLOWS_HTTP_CODE" != "200" ]]; then
    log_error "Failed to retrieve flows (HTTP $FLOWS_HTTP_CODE)"
    exit 1
fi

FLOW_ID=$(echo "$FLOWS_BODY" | sed -E 's/\},[[:space:]]*\{/\}\n\{/g' | grep '"handle":"default-basic-flow"' | grep '"flowType":"AUTHENTICATION"' | grep -o '"id":"[^"]*"' | head -n 1 | cut -d'"' -f4)

if [[ -z "$FLOW_ID" ]]; then
    log_error "Default Basic Authentication Flow ID not found"
    exit 1
fi

log_success "Found Default Basic Authentication Flow ID: $FLOW_ID"
log_info "Updating flow to redirect directly to Google..."

read -r -d '' FLOW_PAYLOAD <<JSON || true
{
  "id": "${FLOW_ID}",
  "handle": "default-basic-flow",
  "name": "Default Basic Authentication Flow",
  "flowType": "AUTHENTICATION",
  "nodes": [
    {
      "id": "start",
      "type": "START",
      "onSuccess": "google_auth"
    },
    {
      "id": "google_auth",
      "type": "TASK_EXECUTION",
      "properties": {
        "idpId": "${GOOGLE_IDP_ID}",
        "allowAuthenticationWithoutLocalUser": true
      },
      "executor": {
        "name": "GoogleOIDCAuthExecutor",
        "inputs": [
          {
            "ref": "input_google_code",
            "type": "TEXT_INPUT",
            "identifier": "code",
            "required": true
          }
        ]
      },
      "onSuccess": "authorization_check"
    },
    {
      "id": "authorization_check",
      "type": "TASK_EXECUTION",
      "executor": {
        "name": "AuthorizationExecutor"
      },
      "onSuccess": "auth_assert"
    },
    {
      "id": "auth_assert",
      "type": "TASK_EXECUTION",
      "executor": {
        "name": "AuthAssertExecutor"
      },
      "onSuccess": "end"
    },
    {
      "id": "end",
      "type": "END"
    }
  ]
}
JSON

FLOW_RESPONSE=$(api_call PUT "/flows/${FLOW_ID}" "${FLOW_PAYLOAD}")
FLOW_HTTP_CODE="${FLOW_RESPONSE: -3}"
FLOW_BODY="${FLOW_RESPONSE%???}"

if [[ "$FLOW_HTTP_CODE" == "200" ]]; then
    log_success "Default Basic Authentication Flow updated to direct Google redirect successfully"
else
    log_error "Failed to update Default Basic Authentication Flow (HTTP $FLOW_HTTP_CODE)"
    echo "Response: $FLOW_BODY"
    exit 1
fi
