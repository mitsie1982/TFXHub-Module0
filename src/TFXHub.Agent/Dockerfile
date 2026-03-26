FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["src/TFXHub.Agent/TFXHub.Agent.csproj", "TFXHub.Agent/"]
RUN dotnet restore "TFXHub.Agent/TFXHub.Agent.csproj"
COPY . .
WORKDIR "/src/src/TFXHub.Agent"
RUN dotnet build "TFXHub.Agent.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "TFXHub.Agent.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "TFXHub.Agent.dll"]