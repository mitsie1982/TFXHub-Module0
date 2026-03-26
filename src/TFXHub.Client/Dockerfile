FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["src/TFXHub.Client/TFXHub.Client.csproj", "TFXHub.Client/"]
RUN dotnet restore "TFXHub.Client/TFXHub.Client.csproj"
COPY . .
WORKDIR "/src/src/TFXHub.Client"
RUN dotnet build "TFXHub.Client.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "TFXHub.Client.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "TFXHub.Client.dll"]