import requests
import urllib3

# Disable SSL warnings for self-signed certs
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# WSO2 IS DCR endpoint
REGISTER_URL = "https://localhost:9443/api/identity/oauth2/dcr/v1.1/register"

# Base64 encoded admin:admin (or your credentials)
import base64
basic_auth = base64.b64encode(b"admin:admin").decode("utf-8")

HEADERS = {
    "Content-Type": "application/json",
    "Authorization": f"Basic {basic_auth}"
}

# -------------------------
# 1️⃣ Register SPA Client
# -------------------------
register_payload = {
    "client_name": "my-spa-client-initial",
    "redirect_uris": [
        "http://localhost:3000/callback"
    ],
    "grant_types": ["client_credentials", "refresh_token"],
    "token_endpoint_auth_method": "none",
    "application_type": "web"
}

print("➡️ Registering SPA via DCR...")

register_res = requests.post(
    REGISTER_URL,
    headers=HEADERS,
    json=register_payload,
    verify=False  # allow self-signed certificate
)

if register_res.status_code != 201:
    print("❌ Registration failed:", register_res.text)
    exit()

client_data = register_res.json()
client_id = client_data["client_id"]

print("✅ Client registered with ID:", client_id)

# -------------------------
# 2️⃣ Update Client (CORS)
# -------------------------
UPDATE_URL = f"{REGISTER_URL}/{client_id}"

update_payload = {
    "client_name": "my-spa-client",
    "redirect_uris": [
        "http://localhost:3000/callback"
    ],
    "grant_types": ["authorization_code", "refresh_token"],
    "token_endpoint_auth_method": "none",
    "application_type": "web",

    # ⭐ THIS IS WHERE CORS IS SET ⭐
    "cors": {
        "cors_enabled": True,
        "allowed_origins": [
            "http://localhost:3000"
        ]
    }
}

print("➡️ Updating client with CORS origins...")

update_res = requests.put(
    UPDATE_URL,
    headers=HEADERS,
    json=update_payload,
    verify=False  # trust self-signed
)

if update_res.status_code not in (200, 201):
    print("❌ Update failed:", update_res.text)
    exit()

print("✅ CORS updated successfully!")
print(update_res.json())