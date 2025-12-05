import fetch from "node-fetch";
import https from "https";
// ====================================================================
//  CONFIGURATION
// ====================================================================
const IS_BASE = "https://localhost:9443";          // WSO2 IS base URL
const TENANT = "carbon.super";                    // Tenant domain
const ADMIN_USER = "admin";
const ADMIN_PASS = "admin";

// Your SPA details
const SPA_NAME = "my-spa-app";
const REDIRECT_URLS = [
    "http://localhost:5173/callback",
    "https://myapp.com/callback"
];
const CORS_ORIGINS = [
    "http://localhost:5173",
    "https://myapp.com"
];

const agent = new https.Agent({
    rejectUnauthorized: false,
});

// ====================================================================
//  1. REGISTER SPA USING DCR
// ====================================================================
async function registerClient() {
    const response = await fetch(`${IS_BASE}/api/identity/oauth2/dcr/v1.1/register`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Authorization": "Basic " + Buffer.from(`${ADMIN_USER}:${ADMIN_PASS}`).toString("base64")
        },
        body: JSON.stringify({
            client_name: SPA_NAME,
            redirect_uris: REDIRECT_URLS,
            grant_types: ["authorization_code"],
            token_endpoint_auth_method: "none" // For SPA
        }),
        agent
    });

    const data = await response.json();
    console.log("DCR Registration Response:", data);

    return data.client_id; // Important: we need this
}

// ====================================================================
//  2. GET FULL APPLICATION DETAILS USING MANAGEMENT API
// ====================================================================
async function getAppId(clientId) {
    const resp = await fetch(
        `${IS_BASE}/t/${TENANT}/api/server/v1/applications?filter=clientId eq "${clientId}"`,
        {
            headers: {
                "Authorization": "Basic " + Buffer.from(`${ADMIN_USER}:${ADMIN_PASS}`).toString("base64")
            }
        }
    );

    const body = await resp.json();
    const app = body.applications?.[0];
    if (!app) throw new Error("Application not found");

    console.log("Found Application:", app.id);
    return app.id;
}

// ====================================================================
//  3. UPDATE APPLICATION: ADD CORS ALLOWED ORIGINS + REDIRECTS
// ====================================================================
async function updateCors(appId) {
    const patchBody = [
        {
            op: "replace",
            path: "/inboundProtocolConfiguration/oidc/callbackURLs",
            value: REDIRECT_URLS
        },
        {
            op: "add",
            path: "/clientOrigin",
            value: CORS_ORIGINS
        }
    ];

    const resp = await fetch(
        `${IS_BASE}/t/${TENANT}/api/server/v1/applications/${appId}`,
        {
            method: "PATCH",
            headers: {
                "Content-Type": "application/json-patch+json",
                "Authorization": "Basic " + Buffer.from(`${ADMIN_USER}:${ADMIN_PASS}`).toString("base64")
            },
            body: JSON.stringify(patchBody)
        }
    );

    const data = await resp.json();
    console.log("CORS Update Response:", data);
}

// ====================================================================
//  RUN EVERYTHING
// ====================================================================
(async function main() {
    try {
        const clientId = await registerClient();
        const appId = await getAppId(clientId);
        await updateCors(appId);
        console.log("🎉 SPA successfully registered & updated with CORS!");
    } catch (err) {
        console.error("❌ Error:", err);
    }
})();
