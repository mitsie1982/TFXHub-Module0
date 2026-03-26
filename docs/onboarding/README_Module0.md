# Module 0 Onboarding

## Apprentice Checklist

- [ ] Clone the repo
- [ ] Open in VS Code devcontainer (if available)
- [ ] Build and run projects
- [ ] Run EF migrations
- [ ] Validate Host, Agent, Client communication
- [ ] Run tests

## Steps

1. **Clone the repo**
   ```
   git clone <repo-url>
   cd TFXHub-Module0
   ```

2. **Open in VS Code**
   ```
   code .
   ```

3. **Build and run projects**
   - Restore: `dotnet restore`
   - Build: `dotnet build`

4. **Run EF migrations**
   - In Package Manager Console (VS): `Add-Migration InitSchema -Project TFXHub.Host`
   - Then: `Update-Database -Project TFXHub.Host`

5. **Validate Host, Agent, Client communication**
   - Run Host: `dotnet run --project src/TFXHub.Host` (runs on http://localhost:5000)
   - Run Agent: `dotnet run --project src/TFXHub.Agent` (calls Host APIs)
   - Run Client: `dotnet run --project src/TFXHub.Client` (interactive CLI to call Host)

6. **Run tests**
   - `dotnet test`

## Containerization

To run with Docker:
```
docker-compose -f infra/docker/docker-compose.yml up
```

## Build and Run Commands

- Build all: `dotnet build`
- Run Host: `dotnet run --project src/TFXHub.Host`
- Run Agent: `dotnet run --project src/TFXHub.Agent`
- Run Client: `dotnet run --project src/TFXHub.Client`

## EF Core Migrations CLI

- Add migration: `Add-Migration InitSchema -Project TFXHub.Host`
- Update database: `Update-Database -Project TFXHub.Host`