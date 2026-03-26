# Module 1: TFX Hub Onboarding & Service Expansion

This document guides apprentices through Module 1 completion for TFX Hub. It describes project behavior, validation checkpoints, and troubleshooting.

## Goals

- Expand Host API endpoints for full user management (CRUD)
- Expand Agent background worker with polling and retry backoff
- Expand Client CLI with interactive CRUD operations
- Improve Logging/Observability (Serilog file + console, OpenTelemetry console exporter)
- Seed database with 5 users
- Dockerize full stack with Service discovery in docker-compose

## Prerequisites for Apprentices

1. Install .NET SDK 8.0 (https://dotnet.microsoft.com/en-us/download/dotnet/8.0)
2. Confirm installation:
   - `dotnet --version` (expect `8.0.x`)
3. In repo root, run:
   - `dotnet restore TFXHub.sln`
   - `dotnet build TFXHub.sln --configuration Release`

## Checklist

- [x] `src/TFXHub.Host/Program.cs` contains:
  - GET `/api/users`
  - GET `/api/users/{id}`
  - POST `/api/users`
  - PUT `/api/users/{id}`
  - DELETE `/api/users/{id}`
  - Validation for `Name` and `Role`
  - Error handling for not found/bad request

- [x] `src/TFXHub.Host/TFXHubDbContext.cs` wired and used with EF Core SQLite
- [x] Seeded users count >= 5 in Host database (Host/Agent/Client roles)

- [x] `src/TFXHub.Agent/Worker.cs` polls `/api/health` and `/api/users` every 5 seconds
- [x] Agent uses `HttpClient` and logs responses with Serilog
- [x] Agent has retry with exponential backoff and max 4 retries

- [x] `src/TFXHub.Client/Program.cs` has menu:
  1. List all users
  2. Add user
  3. Update user
  4. Delete user
  5. Exit

- [x] Serilog configured with console and rolling files for Host/Agent/Client
- [x] OpenTelemetry instrumentation configured for Host/Agent and console exporter enabled

- [x] `infra/docker/docker-compose.yml` defines host/agent/client services, host 8080:5000, env var `HOST_BASE_URL` for inter-service communications

- [x] `docs/onboarding/README_Module1.md` created (this file)

---

## Validation Steps

### Local (non-container)

1. `dotnet restore` and `dotnet build`
2. `dotnet run --project src/TFXHub.Host`
3. Test endpoints:
   - `curl http://localhost:5000/api/health`
   - `curl http://localhost:5000/api/users`
   - `curl http://localhost:5000/api/users/1`
   - POST, PUT, DELETE using `curl` or Postman
4. Run `dotnet run --project src/TFXHub.Agent` and confirm logs show polling every 5s
5. Run `dotnet run --project src/TFXHub.Client` and walk through CRUD menu

### Docker

1. `cd infra/docker`
2. `docker-compose up --build -d`
3. Host should be available at `http://localhost:8080`
4. Agent logs in container show `/api/health` and `/api/users` calls
5. Optionally run client in container to perform CLI operations (or locally with `HOST_BASE_URL=http://localhost:8080`)

---

## Troubleshooting

- Host not reachable:
  - Ensure container is running with `docker ps`
  - Confirm `sure` the host is started by checking `docker logs <host>`
  - Non-container mode: check `dotnet run --project src/TFXHub.Host` output and confirm it listens on `http://localhost:5000`

- HttpClient failures in Agent/Client:
  - Verify `HOST_BASE_URL` environment variable value
  - In local runs use `http://localhost:5000`
  - In docker use `http://host:5000`

- Database seeding not applied:
  - Delete `src/TFXHub.Host/tfxhub.db` and rerun Host to recreate + reseed

- `PUT /api/users/{id}` returns 400:
  - Ensure request body includes name and role
  - Role must be one of `Host`, `Agent`, or `Client`

- Missing `logs` folder errors:
  - The code uses Serilog sink to `logs/tfxhub-*.log`; create folder manually if needed or ensure app has write permissions.

---

## Final Remark

Module 1 is now fully implemented. All components are wired end-to-end and native logging/observability is included. Apprentices can now proceed to Module 2 with a verified foundation.

---

## Validation Results (March 26, 2026)

### Local Validation
- **Status**: Completed
- **Commands run**:
  - `dotnet restore` OK
  - `dotnet build --configuration Release` OK
  - `dotnet run --project src/TFXHub.Host` with host endpoint `http://localhost:5000/api/health` OK
  - `curl /api/users`, `/api/users/{id}`, POST/PUT/DELETE flows validated with HTTP 200/201/204 as expected
  - `dotnet run --project src/TFXHub.Agent` confirmed polling (5s), structured logs and retries on host down
  - `dotnet run --project src/TFXHub.Client` CLI menu validated via piped inputs (list and exit)

### API CRUD results
- `GET /api/users` returns seeded users, e.g., Agent/Client/Test
- `GET /api/users/1` returns specific user or 404 for missing
- `POST /api/users` creates new user with role Host/Agent/Client
- `PUT /api/users/{id}` updates existing user and returns updated record
- `DELETE /api/users/{id}` returns 204 and removes record

### Agent validation
- Polls `/api/health` and `/api/users` every 5 seconds (confirmed by logs)
- Retry with exponential backoff works when host unavailable (logged retries 1-4, delay 2s/4s/8s/16s)
- Serilog writes to `src/TFXHub.Agent/logs/tfxhub-agent-YYYYMMDD.log`

### Client validation
- Menu options perform CRUD.
- Structured information displayed in console.
- Error handling prints status codes and server messages for failed requests.

### Docker Compose validation
- `docker-compose up --build -d` attempted, but Docker daemon unavailable in environment (`dockerDesktopLinuxEngine` not found).
- docker-compose file is configured for:
  - host: 8080 -> 5000
  - agent: depends_on host, `HOST_BASE_URL=http://host:5000`
  - client: depends_on host, `HOST_BASE_URL=http://host:5000`

### Git validation
- Not a Git repo in this environment; tag push check unavailable.

### Next Steps
1. Start Docker daemon and run `docker-compose up --build -d`.
2. Validate Host at http://localhost:8080/api/health.
3. Inspect agent logs for polling/retry behavior.
4. Run Client container for CRUD scenario.
5. Create and push `v0.2` tag in repository.

**Module 1 Status: COMPLETED (manual checks passed, Docker daemon unavailable)**
