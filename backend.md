# Apto SKR Backend — App Integration Guide

This project is a Node.js + TypeScript backend for a SKR accrual and redemption flow. It is designed to be integrated with an Android app or any mobile/web client without forcing user login friction.

The backend uses:
- Express.js for the API
- PostgreSQL on Neon for ledger state
- Solana RPC for treasury transfers when demo mode is disabled
- A single shared app API key for backend authentication
- A ledger-based reward model instead of per-tap on-chain payouts

---

## 1. What this backend does

The app does not immediately transfer SKR on every payment. Instead, it follows a ledger model:

1. App submits a payment confirmation with transaction signature and user wallet.
2. Backend validates the payment and rolls a reward tier.
3. Reward is added to the user’s accrued balance in the database.
4. User sees their balance in the app.
5. When the user redeems, the backend checks treasury liquidity and either:
   - pays instantly if enough liquid reserve is available, or
   - marks the request as delayed and processes it later if reserve is low.

This is intentionally designed to avoid expensive chain operations on every reward event while keeping accounting accurate.

---

## 2. High-level integration flow

### App flow

1. User connects wallet / chooses wallet address.
2. User pays via app or wallet payment action.
3. App sends payment confirmation request to backend.
4. Backend accrues reward into DB.
5. App fetches user balance from backend.
6. App shows available SKR balance.
7. User taps Redeem.
8. App hits redemption API.
9. Backend updates ledger and optionally sends token transfer.

### Important backend rule

Your app should not try to do a user-login flow for this backend. The intended integration is:
- one shared backend secret in the app
- Authorization header attached to all protected backend requests
- no per-user auth session required

---

## 3. Frontend values required by the app

These values are required in the Android app or frontend:

```env
APP_API_KEY=<same_value_as_backend_APP_API_KEY>
BASE_URL=https://apto-backend.onrender.com
AUTH_HEADER_NAME=authorization
AUTH_SCHEME=Bearer
```

### What the app needs to send

Every protected request must include:

```http
Authorization: Bearer <APP_API_KEY>
```

### What the app does NOT need

These values must stay on the server and must never be exposed to the client app:

```env
REWARD_SECRET=
TREASURY_PRIVATE_KEY=
DB_URL=
SKR_MINT=
```

`REWARD_SECRET` is used only to compute reward tier logic inside the backend.
`TREASURY_PRIVATE_KEY` is used for treasury token payout signing.
`DB_URL` is the Neon database connection string.
`SKR_MINT` is the real token mint on the correct network and is only needed on the server for real payout mode.

If the app is in demo mode, `SKR_MINT` can stay empty and the backend will only allow the demo cap.

---

## 4. Security model

### Shared API key auth

The backend validates a single shared secret from the app. This is configured via environment variables:

```env
APP_API_KEY=replace-with-long-random-string
AUTH_ENABLED=true
AUTH_HEADER_NAME=authorization
AUTH_SCHEME=Bearer
```

The middleware accepts either:
- `Authorization: Bearer <APP_API_KEY>`
- or `Authorization: <APP_API_KEY>` when `AUTH_SCHEME` is not bearer

The backend checks the configured header name and compares against `APP_API_KEY`.

If the key is missing or wrong, it returns:
- status `401`
- error: `Missing API key` or `Invalid API key`

This keeps the integration smooth for mobile apps while still protecting the backend.

### OWASP baseline included

The backend already uses:
- Helmet
- rate limiting
- CORS restriction
- JSON size limit
- no X-Powered-By header
- restricted allowed origins

This is important for app security and preventing abuse.

---

## 5. Backend URL and environment details

### Local development

Use your local backend URL while testing on your machine, for example:

```text
https://your-local-backend-domain-or-ngrok-url
```

### Deployed backend

Use the deployed backend URL in the app, for example:

```text
https://apto-backend.onrender.com
```

This is the production backend URL used in the current setup.

---

## 6. Required environment variables

Example values are in `.env.example`.

```env
PORT=4000
DB_URL=your_neon_db_url
RPC_URL=https://api.devnet.solana.com
TREASURY_WALLET=your_treasury_wallet
TREASURY_PRIVATE_KEY=your_treasury_private_key
SKR_MINT=your_skr_token_mint
SKR_TOKEN_DECIMALS=9
REWARD_SECRET=change-me
APP_API_KEY=some-long-random-secret
AUTH_ENABLED=true
AUTH_HEADER_NAME=authorization
AUTH_SCHEME=Bearer
ALLOWED_ORIGINS=https://your-frontend-domain.com,https://app.example.com
RATE_LIMIT_MAX=100
RATE_LIMIT_WINDOW_MS=900000
RESERVE_RATIO_TARGET=0.30
RESERVE_RATIO_FLOOR=0.20
RESERVE_RATIO_CEILING=0.40
REDEMPTION_POLL_HOURS=48
ENABLE_DEMO_MODE=true
DEMO_TEST_AMOUNT_SKR=0.6
```

### Must be set in app environment

For the app to work cleanly:
- `APP_API_KEY` must match the app secret
- `AUTH_ENABLED` must be `true`
- `ALLOWED_ORIGINS` must include your app origin or emulator origin
- `ENABLE_DEMO_MODE` should be `true` during testing
- `DEMO_TEST_AMOUNT_SKR` should be set to a safe test amount like `0.6`

---

## 7. CORS and app origin handling

The backend rejects requests from disallowed origins using CORS.

In the app, if you are using a webview or web app, make sure the allowed origin includes your client domain or emulator origin.

Examples of valid allowed origins:
```text
https://your-frontend-domain.com
https://app.example.com
https://your-production-webapp.com
```

If your app is a native Android app, this is usually not a browser CORS issue because the request is made from code directly, not from a browser page. But the backend still restricts origins by request origin header, so allow your app host origin if applicable.

---

## 8. API endpoints your app must call

## 8.1 Health check

This endpoint is public and does not require auth.

```http
GET /health
```

Example response:

```json
{
  "ok": true,
  "service": "apto-backend",
  "timestamp": "2026-09-24T12:00:00.000Z"
}
```

Use this to verify the backend is reachable before other calls.

---

## 8.2 Confirm payment and accrue reward

Endpoint:

```http
POST /payment/confirm
```

Headers:

```http
Content-Type: application/json
Authorization: Bearer <APP_API_KEY>
```

Body:

```json
{
  "txSig": "<solana_signature>",
  "userPubkey": "<wallet_public_key>",
  "amountUsd": 12.5
}
```

Example response:

```json
{
  "success": true,
  "paymentId": 42,
  "alreadyProcessed": false,
  "accrued": 0.48,
  "tier": "gold",
  "seed": "abc123..."
}
```

### In-app notes

- `txSig` must be the actual payment or wallet transaction hash.
- `userPubkey` should be the user wallet public key that receives the reward.
- `amountUsd` should be the USD value of the payment or spend event.
- The backend is idempotent on `tx_sig`, so duplicate submissions are safely ignored.

---

## 8.3 Get user balance

Endpoint:

```http
GET /redeem/balance/:userPubkey
```

Headers:

```http
Authorization: Bearer <APP_API_KEY>
```

Example:

```http
GET /redeem/balance/6Uq...abc
```

Example response:

```json
{
  "accruedSkr": 2.35,
  "lifetimeEarnedSkr": 18.9,
  "redeemEtaIfRequestedNow": "available_now"
}
```

Possible values for `redeemEtaIfRequestedNow`:
- `available_now`
- `up_to_48_hours`

### In-app notes

- Use this endpoint to display the current acquired SKR balance.
- If it says `up_to_48_hours`, tell the user it is not instantly redeemable due to liquidity or treasury processing.

---

## 8.4 Request redemption

Endpoint:

```http
POST /redeem
```

Headers:

```http
Content-Type: application/json
Authorization: Bearer <APP_API_KEY>
```

Body:

```json
{
  "userPubkey": "<wallet_public_key>",
  "amountSkr": 0.6
}
```

Example response:

```json
{
  "success": true,
  "id": 22,
  "status": "instant_paid",
  "eta": null,
  "payoutTxSig": "abc123..."
}
```

If not enough liquidity:

```json
{
  "success": true,
  "id": 23,
  "status": "delayed_unstaking",
  "eta": "2026-09-26T12:00:00.000Z",
  "payoutTxSig": null
}
```

### In-app notes

- Only allow redemption amounts that do not exceed the current accrued balance.
- If `ENABLE_DEMO_MODE` is true, the backend enforces a cap such as `0.6` SKR.
- If you are not in demo mode, actual token transfer can happen if treasury liquidity and configuration are valid.

---

## 8.5 Treasury status

Endpoint:

```http
GET /treasury/status
```

Headers:

```http
Authorization: Bearer <APP_API_KEY>
```

Use this only for internal or admin verification. It is useful to inspect reserve ratio and treasury health.

---

## 9. Android app integration example

Below is a Kotlin Retrofit example showing how to integrate with the backend.

```kotlin
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.Headers
import retrofit2.http.POST
import retrofit2.http.Path

interface AptoApiService {

    @GET("/health")
    suspend fun health(): HealthResponse

    @POST("/payment/confirm")
    @Headers("Content-Type: application/json")
    suspend fun confirmPayment(
        @Header("Authorization") token: String,
        @Body body: PaymentConfirmRequest
    ): PaymentConfirmResponse

    @GET("/redeem/balance/{userPubkey}")
    suspend fun getBalance(
        @Header("Authorization") token: String,
        @Path("userPubkey") userPubkey: String
    ): BalanceResponse

    @POST("/redeem")
    @Headers("Content-Type: application/json")
    suspend fun redeem(
        @Header("Authorization") token: String,
        @Body body: RedemptionRequest
    ): RedemptionResponse
}
```

### Request models

```kotlin
data class PaymentConfirmRequest(
    val txSig: String,
    val userPubkey: String,
    val amountUsd: Double
)

data class RedemptionRequest(
    val userPubkey: String,
    val amountSkr: Double
)
```

### Wrapper usage

```kotlin
val apiKey = "YOUR_APP_API_KEY"
val authHeader = "Bearer $apiKey"

val result = api.confirmPayment(
    token = authHeader,
    body = PaymentConfirmRequest(
        txSig = txSignature,
        userPubkey = walletAddress,
        amountUsd = 12.5
    )
)
```

### Recommended Android pattern

- Store `APP_API_KEY` in `BuildConfig` or secure storage, not in plain source code.
- Add a single API client singleton in your app.
- Add all backend calls through a repository layer.
- Report `401` errors as “service unavailable / invalid backend key”.
- Log only sanitized errors; do not expose full backend details to users.

---

## 10. Recommended app-side behavior

### 9.1 Show balance from backend, not from local assumptions

Do not trust the app-only balance value. Always fetch from backend before showing the SKR balance.

Pseudo-flow:

```text
Load wallet -> fetch /redeem/balance/{userPubkey} -> render balance
```

### 9.2 Use transaction signature only after payment success

When the user completes a payment:
1. Wait for the wallet/payment SDK to return a valid transaction signature.
2. Submit `txSig` to `/payment/confirm`.
3. Show loading spinner until backend returns success.
4. Refresh the wallet balance.

### 9.3 Guard redemption amount

Before sending redemption request:
- check user balance is loaded
- verify requested amount is > 0
- verify requested amount <= accrued balance
- show clear message if the app is in demo mode and the cap is lower

### 9.4 Handle delayed redemption gracefully

If the response says `delayed_unstaking`, the app should show:
- “Your reward is being processed. It may take up to 48 hours.”
- Avoid showing it as failed.
- Allow the user to check status again later.

### 9.5 Secure secret handling

For Android:
- use `BuildConfig` or encrypted preferences
- do not hardcode the key into source code
- avoid putting the secret in logs or crash reports
- rotate keys periodically if needed

---

## 11. Demo mode vs real mode

### Demo mode

Set:

```env
ENABLE_DEMO_MODE=true
DEMO_TEST_AMOUNT_SKR=0.6
```

This allows safe testing with a cap, without sending real SKR on-chain.

### Real production mode

Set:

```env
ENABLE_DEMO_MODE=false
SKR_MINT=<real_mint_address>
TREASURY_WALLET=<real_treasury_wallet>
TREASURY_PRIVATE_KEY=<real_private_key>
```

Requirements before real transfers:
- real mint is configured
- treasury wallet has token balance
- wallet is funded correctly
- correct token account exists for payout destination
- treasury reserve and liquidity logic is validated

---

## 12. Local testing checklist

Before integrating, test these steps locally:

1. Start backend:
   ```bash
   npm install
   npm run dev
   ```
2. Check health:
   ```bash
   curl https://apto-backend.onrender.com/health
   ```
3. Test auth rejection without header:
   ```bash
   curl https://apto-backend.onrender.com/treasury/status
   ```
4. Test auth success with correct header:
   ```bash
   curl -H "Authorization: Bearer YOUR_APP_API_KEY" https://apto-backend.onrender.com/treasury/status
   ```
5. Simulate payment confirm with test wallet and amount.
6. Check balance endpoint.
7. Use demo mode to redeem a small safe amount.
8. Verify the response payload and app UI handling.

---

## 13. Troubleshooting

### 401 unauthorized

Possible causes:
- missing `Authorization` header
- wrong app key value
- wrong `AUTH_SCHEME`
- backend env not loaded in Render

### 403 CORS origin not allowed

Possible causes:
- `ALLOWED_ORIGINS` missing app host
- using local emulator host incorrectly
- backend sees the wrong origin

### 500 internal server error

Possible causes:
- database not initialized
- missing `DB_URL`
- treasury wallet config missing
- invalid token mint or wallet config

### Balance shows zero unexpectedly

Possible causes:
- payment confirm failed or was not called
- wrong wallet public key passed
- DB not seeded
- reward calculation did not run

---

## 14. Production advice

For production-grade deployment:
- move treasury keys to a proper secure secret manager
- use a dedicated backend service account or key management system
- rotate secret keys periodically
- monitor treasury reserve ratio and redemption velocity
- use actual token account validation before payouts
- keep demo mode disabled in production

---

## 15. Summary

For your app integration, the key rule is simple:

- do not create user login friction
- send a shared backend secret in the Authorization header
- hit the backend endpoints exactly as defined above
- refresh user balance after pay and redeem flows
- handle delayed redemption states gracefully in the UI
- keep demo mode on while testing

This is the cleanest path for a mobile app to work with this backend without making users sign in again and again.

---

## 16. Quick copy-paste example

### Backend call example

```bash
curl -X POST https://apto-backend.onrender.com/payment/confirm \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_APP_API_KEY" \
  -d '{
    "txSig": "demo_signature_123",
    "userPubkey": "demo_wallet_pubkey",
    "amountUsd": 10
  }'
```

### Balance request

```bash
curl -H "Authorization: Bearer YOUR_APP_API_KEY" \
  https://apto-backend.onrender.com/redeem/balance/demo_wallet_pubkey
```

### Redemption request

```bash
curl -X POST https://apto-backend.onrender.com/redeem \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_APP_API_KEY" \
  -d '{
    "userPubkey": "demo_wallet_pubkey",
    "amountSkr": 0.6
  }'
```

---
