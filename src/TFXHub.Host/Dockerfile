FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 5000

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["src/TFXHub.Host/TFXHub.Host.csproj", "TFXHub.Host/"]
RUN dotnet restore "TFXHub.Host/TFXHub.Host.csproj"
COPY . .
WORKDIR "/src/src/TFXHub.Host"
RUN dotnet build "TFXHub.Host.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "TFXHub.Host.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "TFXHub.Host.dll"]