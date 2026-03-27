# Module 2 Build & Validation Report

**Date:** March 26, 2026  
**Workspace Root:** `C:\Users\1hans\TFXHub-Module0`

## 1) Compile status

### Commands executed
- `dotnet restore`
- `dotnet build`

### Result
- **Restore:** Success (`All projects are up-to-date for restore.`)
- **Build:** Success

```text
TFXHub.Client -> ...\src\TFXHub.Client\bin\Debug\net8.0\TFXHub.Client.dll
TFXHub.Agent  -> ...\src\TFXHub.Agent\bin\Debug\net8.0\TFXHub.Agent.dll
TFXHub.Host   -> ...\src\TFXHub.Host\bin\Debug\net8.0\TFXHub.Host.dll

Build succeeded.
    0 Warning(s)
    0 Error(s)
```

### Compiler diagnostics (CSxxxx)
- **None found**.
- No CS5001 detected for `TFXHub.Host`; `src/TFXHub.Host/Program.cs` already exists and compiles.

---

## 2) Package drift (outdated scan)

### Command set
- `dotnet list src/TFXHub.Host/TFXHub.Host.csproj package --outdated`
- `dotnet list src/TFXHub.Agent/TFXHub.Agent.csproj package --outdated`
- `dotnet list src/TFXHub.Client/TFXHub.Client.csproj package --outdated`

### Host drifted packages
- `Microsoft.EntityFrameworkCore` `8.0.25 -> 10.0.5`
- `Microsoft.EntityFrameworkCore.Sqlite` `8.0.25 -> 10.0.5`
- `Microsoft.EntityFrameworkCore.Tools` `8.0.25 -> 10.0.5`
- `Serilog.AspNetCore` `8.0.3 -> 10.0.0`
- `Serilog.Settings.Configuration` `8.0.4 -> 10.0.0`
- `Serilog.Sinks.File` `5.0.0 -> 7.0.0`
- `Swashbuckle.AspNetCore` `6.9.0 -> 10.1.7`

### Agent drifted packages
- `Microsoft.Extensions.Hosting` `8.0.1 -> 10.0.5`
- `Serilog.AspNetCore` `8.0.3 -> 10.0.0`
- `Serilog.Sinks.File` `5.0.0 -> 7.0.0`

### Client drifted packages
- `Serilog` `3.1.1 -> 4.3.1`
- `Serilog.Sinks.Console` `5.0.1 -> 6.1.1`
- `Serilog.Sinks.File` `5.0.0 -> 7.0.0`
- `System.Net.Http.Json` `8.0.1 -> 10.0.5`

### Drift interpretation
- Current package set is pinned to **net8-compatible stable versions**.
- Reported newer versions are mostly **major upgrades** (10.x / 7.x) and not required for this remediation pass.
- `Swashbuckle.AspNetCore` is already pinned to `6.9.0` (NU1603 issue previously mitigated).

---

## 3) Test results

### Command executed
- `dotnet test`

### Result
- Restore step executed successfully.
- No unit/integration test projects were discovered/executed in current solution.
- No stack traces produced because no failing tests were run.

---

## 4) Project readiness for runtime validation

- **TFXHub.Host:** Builds cleanly, ready.
- **TFXHub.Agent:** Builds cleanly, ready.
- **TFXHub.Client:** Builds cleanly, ready.

Overall status: ✅ **All projects compile cleanly and are ready for runtime validation.**

---

## 5) Code fixes applied in this pass

- **No new code patches required** during this build validation pass.
- Existing `Program.cs` in `src/TFXHub.Host` is present and valid.

### Diff snippets
```diff
# No file changes were necessary in this run.
```
