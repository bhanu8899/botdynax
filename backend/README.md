# BotDyNax Backend

NestJS + TypeScript cloud backend for the BotDyNax app: auth, robot fleet management, and live telemetry (REST + WebSocket + MQTT bridge).

## Stack

- **NestJS** (Express) — REST API, modular Clean-Architecture-style structure
- **Prisma** + **SQLite** for local dev (zero install) — swap to Postgres for staging/production by changing `prisma/schema.prisma`'s `provider` and `DATABASE_URL`
- **Mosquitto** (or any MQTT broker) — real-time robot telemetry, matching the app's `MQTTTransport` topic contract
- **Raw WebSocket** (`@nestjs/platform-ws`, not Socket.IO) at `/robots` — matches the app's `WifiTransport`, which uses `web_socket_channel` (plain RFC6455 framing)
- **JWT** access + refresh tokens, Google/Apple ID token verification, guest sessions

## Running locally

1. Copy `.env.example` to `.env` (already done) and adjust secrets as needed.
2. Make sure a local MQTT broker is running (Mosquitto was installed alongside this project; start it with `mosquitto` on its default port 1883, or point `MQTT_URL` at any broker).
3. Install dependencies: `npm install`
4. Generate the Prisma client and create the local SQLite database:
   ```
   npm run prisma:generate
   npm run prisma:migrate
   ```
5. Start the dev server: `npm run start:dev`

The API is served under `http://localhost:3000/api/v1`. The robot WebSocket endpoint is `ws://localhost:3000/robots?robotId=<id>&token=<accessToken>`.

## Module layout

- `auth/` — register/login/refresh/guest/google/apple/forgot-password
- `users/` — profile
- `robots/` — fleet CRUD, command dispatch (→ MQTT), the `/robots` WebSocket gateway
- `mqtt/` — bridges the Mosquitto broker into the rest of the backend (`MqttBridgeService.robotFrames$`)
- `schedules/`, `history/`, `accessories/`, `notifications/` — per-robot resources, all scoped to the authenticated owner
- `tuya/` — proxies Tuya's Cloud API for BotDyNax devices built on Tuya-certified hardware; see below

## Tuya Cloud setup

Devices that run on Tuya-certified modules are onboarded through Tuya's Cloud API rather than direct BLE/WiFi/MQTT. The Tuya Client Secret is a shared-secret HMAC key and must **never** be embedded in the mobile app — this module holds it server-side and the app only ever talks to `/tuya/*` on this backend.

1. Create a Cloud Development project at [Tuya IoT Platform](https://iot.tuya.com) and note its **Client ID**, **Client Secret**, and data-center base URL (US/EU/CN/IN — matches `TUYA_BASE_URL`).
2. Under the project's Devices tab, enable **Link Tuya App Account** and note the generated **schema** id.
3. Set `TUYA_CLIENT_ID`, `TUYA_CLIENT_SECRET`, `TUYA_SCHEMA`, `TUYA_BASE_URL`, and `TUYA_REDIRECT_URI` in `.env`.
4. Verify the exact "Link Tuya App Account" authorization URL and code-exchange endpoint shown in your project's own panel — `TuyaService.getAuthUrl`/`linkAccount` use Tuya's documented pattern but these two specific paths are worth confirming against your project, since Tuya has changed them across API versions. Everything else (request signing, project token, device list/status/functions/commands) uses Tuya's stable, long-standing OpenAPI v1.0 endpoints.

## Swapping to Postgres for production

1. In `prisma/schema.prisma`, change `provider = "sqlite"` to `provider = "postgresql"`.
2. Set `DATABASE_URL` to your Postgres connection string.
3. Re-run `npm run prisma:migrate`.

Nothing else in the codebase needs to change — every model here is Postgres-compatible as written.
