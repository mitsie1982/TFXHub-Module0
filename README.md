# TFX Hub Module 0

This is the foundation module for TFX Hub, a platform connecting service professionals to homeowners via WhatsApp and a professional database.

## Architecture

- **TFXHub.Host**: ASP.NET Core Web API with minimal APIs, EF Core database.
- **TFXHub.Agent**: Worker Service for background tasks, communicating with Host.
- **TFXHub.Client**: Console App for user interaction with the APIs.

## Getting Started

1. Clone the repo.
2. Open in VS Code.
3. Run `dotnet restore`
4. Run `dotnet build`
5. For database: `dotnet ef database update --project src/TFXHub.Host`
6. Run the Host: `dotnet run --project src/TFXHub.Host`
7. Run the Agent: `dotnet run --project src/TFXHub.Agent`
8. Run the Client: `dotnet run --project src/TFXHub.Client`

## Containerization

Use docker-compose in /infra/docker

## CI/CD

GitHub Actions in .github/workflows