# Local Development Guide — Google Federation

This guide explains how to set up and test the **Google Direct Federation** flow locally for both the **Online Passport App** and the **Consent Portal**.

## Prerequisites

- Docker and Docker Compose
- `jq` CLI tool (`brew install jq` on macOS)
- A Google Cloud project with OAuth 2.0 credentials

---

## 1. Create Google OAuth Credentials

1. Go to [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials)
2. Click **Create Credentials** → **OAuth Client ID**
3. Application type: **Web application**
4. Add the following **Authorized redirect URIs**:
   - `http://localhost:3000/login` (Passport App)
   - `https://localhost:8090/gate/signin` (ThunderID / Consent Portal)
5. Copy the **Client ID** and **Client Secret**

---

## 2. Configure Environment Variables

Edit `ndx/.env` and set the following values:

### Required — Google OAuth Credentials

```env
GOOGLE_CLIENT_ID=your-actual-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-your-actual-secret
```

### Optional — Federated User Account Linking

To link your Google account with a local ThunderID user (so the NDX data exchange works after login), uncomment and fill in the `FED_USER_*` variables:

```env
FED_USER_USERNAME=your-google-username
FED_USER_EMAIL=your-google-email@gmail.com
FED_USER_GIVEN_NAME=YourFirstName
FED_USER_FAMILY_NAME=YourLastName
```

> **Note:** The `FED_USER_EMAIL` must match the email of the Google account you'll sign in with. This is how ThunderID links the federated Google identity to a local user.

---

## 3. Run the Stack

```bash
./init.sh
```

This will:
1. Start all NDX infrastructure (ThunderID, PostgreSQL, API Gateway, etc.)
2. Configure the Google Identity Provider in ThunderID
3. Create the federated user (if `FED_USER_*` variables are set)
4. Start member services (Passport App, DRP, RGD, etc.)

### What init.sh Prints

At the end, you'll see a summary like:

```
[SUCCESS] Google Federation: Enabled ✓
[INFO]   Click 'Sign in with Google' on the Passport App to test
```

If you see `Google Federation: Not configured`, double-check your `GOOGLE_CLIENT_ID` in `ndx/.env`.

---

## 4. Test the Flow

### Passport App (http://localhost:3000)

1. Open http://localhost:3000
2. Click **Sign in with Google**
3. Authenticate with your Google account
4. The app exchanges your Google token with ThunderID for an NDX access token
5. You should see the passport application form

### Consent Portal (http://localhost:5173)

1. Open http://localhost:5173
2. You'll be redirected to ThunderID → Google for authentication
3. After Google sign-in, ThunderID processes the federation and returns you to the Consent Portal
4. Review and approve/reject consent requests

---

## Architecture Overview

```
┌─────────────┐     ┌──────────────┐     ┌────────────┐
│  Browser     │────▶│ Passport App │────▶│  Google    │
│             │◀────│ :3000        │◀────│  OAuth     │
└─────────────┘     └──────┬───────┘     └────────────┘
                           │ RFC 8693
                           │ Token Exchange
                           ▼
                    ┌──────────────┐
                    │  ThunderID   │
                    │  :8090       │
                    └──────────────┘
                           ▲
                           │ OIDC
┌─────────────┐     ┌──────┴───────┐
│  Browser     │────▶│ Consent      │
│             │◀────│ Portal :5173 │
└─────────────┘     └──────────────┘
```

**Passport App flow:** The app handles Google OAuth directly, then exchanges the Google `id_token` with ThunderID via [RFC 8693 Token Exchange](https://datatracker.ietf.org/doc/html/rfc8693).

**Consent Portal flow:** The portal uses ThunderID's built-in OIDC login, which redirects to Google via the configured authentication flow.

---

## Key Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `GOOGLE_CLIENT_ID` | _(must set)_ | Google OAuth Client ID |
| `GOOGLE_CLIENT_SECRET` | _(must set)_ | Google OAuth Client Secret |
| `FED_USER_USERNAME` | _(optional)_ | Username for the federated test user |
| `FED_USER_EMAIL` | _(optional)_ | Email for the federated test user (must match Google account) |
| `FED_USER_GIVEN_NAME` | _(optional)_ | First name for the federated test user |
| `FED_USER_FAMILY_NAME` | _(optional)_ | Last name for the federated test user |
| `IDP_BROWSER_URL` | `https://localhost:8090` | Browser-accessible ThunderID URL |
| `IDP_BASE_URL` | `https://thunderid:8090` | Internal Docker ThunderID URL |
| `PASSPORT_CLIENT_SECRET` | `1234` | Shared secret between Passport App and ThunderID |
| `APP_BASE_URL` | `http://localhost:3000` | Passport App base URL for OAuth redirects |
| `CLEAN_START` | `true` | Set to `false` to preserve data between runs |

---

## Troubleshooting

### "Failed to authenticate user via Google and ThunderID OIDC" (500 error)

- Check that `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are set correctly in `ndx/.env`
- Verify the redirect URI `http://localhost:3000/login` is listed in Google Cloud Console
- Check container logs: `docker logs online-passport-app`

### Google redirects to wrong URL

- Ensure `IDP_BROWSER_URL=https://localhost:8090` in `ndx/.env` (not `thunderid:8090`)
- Ensure `https://localhost:8090/gate/signin` is listed in Google's authorized redirect URIs

### Federated user not created

- Ensure `FED_USER_USERNAME` and `FED_USER_EMAIL` are uncommented in `ndx/.env`
- Check that values are not the default placeholders
- Run with `CLEAN_START=true` (default) to recreate from scratch

### Consent Portal can't reach ThunderID

- ThunderID must be accessible at `https://localhost:8090` from the browser
- Accept the self-signed certificate by visiting https://localhost:8090 directly
