# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files first for layer caching
COPY TFXHub.sln ./
COPY src/TFXHub.Host/TFXHub.Host.csproj src/TFXHub.Host/
COPY src/TFXHub.Agent/TFXHub.Agent.csproj src/TFXHub.Agent/
COPY src/TFXHub.Client/TFXHub.Client.csproj src/TFXHub.Client/
COPY tests/TFXHub.Tests/TFXHub.Tests.csproj tests/TFXHub.Tests/

RUN dotnet restore TFXHub.sln

# Copy everything and publish host
COPY . .
RUN dotnet publish src/TFXHub.Host/TFXHub.Host.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:80
EXPOSE 80

ENTRYPOINT ["dotnet", "TFXHub.Host.dll"]
