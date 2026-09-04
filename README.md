# tipster
A web-based platform for digital tipping and personal micropayments via QR codes. Scan, tip, pay. No app or account required.

## Modules

- `backend/user-service` – Micronaut service, port `8081`
- `backend/payment-service` – Micronaut service, port `8082`
- `frontend` – React/TypeScript frontend with Vite, port `3000`

## Prerequisites

- Java 17 or newer
- Node.js 20 or newer with npm

## Build and test

Build and test the complete monorepo through Gradle:

```shell
./gradlew build
```

Run a backend service:

```shell
./gradlew :backend:user-service:run
```

Start the frontend development server:

```shell
cd frontend
npm install
npm run dev
```

## Docker Compose

The local setup mirrors Tockly's split between infrastructure and application
services. It starts PostgreSQL, MinIO and MailHog without an external payment
provider or public webhook tunnel.

Start only the infrastructure:

```shell
./docker-compose/start_infra.sh
```

Build and start the complete stack:

```shell
./docker-compose/start_tipster.sh --build
```

Stop the stack while keeping its data:

```shell
./docker-compose/stop_tipster.sh
```

The frontend is available at `http://localhost:3000`. MailHog runs at
`http://localhost:8025` and the MinIO console at `http://localhost:9001`.
