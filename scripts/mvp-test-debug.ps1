<#
TFXHub: Automated MVP Test and Debug Script
Run from repository root in VS Code PowerShell terminal.

Configure variables below before running.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -------------------------
# Configuration (edit only)
# -------------------------
$GITHUB_PAT = ""                              # Optional: PAT to create GitHub issues
$OWNER_REPO = "your-org/your-repo"            # owner/repo for issue creation if PAT provided
$E2E_TIMEOUT_SECONDS = 300
$PERF_SMOKE_DURATION = 10                     # seconds for perf smoke test
$PERF_SMOKE_CONCURRENCY = 10
$DOCKER_IMAGE = "tfxhub-demo:verify"
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
  throw "Not inside a git repository. Run this script from the repository root."
}
$REPORT_DIR = Join-Path $repoRoot "docs\reports"
$REPORT_FILE = Join-Path $REPORT_DIR "module2_remediation_report.md"
$LOG_DIR = Join-Path $REPORT_DIR "logs"
$HEALTH_ENDPOINT = "http://localhost:8080/health"  # adjust to your app
# -------------------------

# Ensure report directories
if (-not (Test-Path $REPORT_DIR)) { New-Item -ItemType Directory -Path $REPORT_DIR -Force | Out-Null }
if (-not (Test-Path $LOG_DIR)) { New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null }

$ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$summary = [System.Collections.Generic.List[string]]::new()
$failures = [System.Collections.Generic.List[string]]::new()
$automationLog = Join-Path $LOG_DIR "automation.log"

function Log-Add([string]$line) {
  $line | Tee-Object -FilePath $automationLog -Append
}

function Has-NpmScript([string]$name) {
  if (-not (Test-Path "package.json")) { return $false }
  try {
    $pkg = Get-Content "package.json" -Raw | ConvertFrom-Json
    return $null -ne $pkg.scripts.$name
  } catch {
    return $false
  }
}

function Run-Step([string]$name, [scriptblock]$action) {
  Log-Add "`n--- $name ---"
  $stepLog = Join-Path $LOG_DIR ("step_" + ($name -replace '\s+','_') + ".log")

  try {
    $script:LASTEXITCODE = 0
    & $action 2>&1 | Tee-Object -FilePath $stepLog -Append

    if ($LASTEXITCODE -ne 0) {
      throw "Exit code $LASTEXITCODE"
    }

    Log-Add "${name}: SUCCESS"
    $summary.Add("${name}: SUCCESS")
    return $true
  } catch {
    Log-Add "${name}: FAILURE - $($_.Exception.Message)"
    $failures.Add("${name}: $($_.Exception.Message)")
    $summary.Add("${name}: FAILURE")
    return $false
  }
}

Log-Add "=== MVP Test and Debug Run - $ts ==="

Push-Location $repoRoot
try {
  # -------------------------
  # 1) Detect project type
  # -------------------------
  $isDotnet = @(Get-ChildItem -Path . -Filter "*.csproj" -Recurse -File -ErrorAction SilentlyContinue).Count -gt 0
  $isNode = Test-Path "package.json"
  $isPython = (Test-Path "pyproject.toml") -or (Test-Path "requirements.txt")
  Log-Add "Project detection: dotnet=$isDotnet node=$isNode python=$isPython"

  # -------------------------
  # 2) Run lint and unit tests
  # -------------------------
  if ($isNode) {
    if (Has-NpmScript "lint") {
      Run-Step "Lint (npm)" { npm run lint }
    } else {
      Log-Add "No npm lint script detected"
    }
  } elseif ($isDotnet) {
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
      Run-Step "Format/Analyze (dotnet)" { dotnet format --verify-no-changes }
    } else {
      Log-Add "dotnet CLI not available"
    }
  } elseif ($isPython) {
    Run-Step "Lint (ruff/flake8)" {
      if (Get-Command ruff -ErrorAction SilentlyContinue) {
        ruff check .
      } elseif (Get-Command flake8 -ErrorAction SilentlyContinue) {
        flake8 .
      } else {
        Write-Output "No linter installed"
      }
    }
  } else {
    Log-Add "No recognized project type for lint step"
  }

  if ($isDotnet) {
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
      Run-Step "Unit tests (dotnet test)" { dotnet test --no-build --verbosity minimal }
    } else {
      Log-Add "dotnet CLI not available"
    }
  } elseif ($isNode) {
    if (Has-NpmScript "test") {
      Run-Step "Unit tests (npm test)" { npm test --silent }
    } else {
      Log-Add "No npm test script detected"
    }
  } elseif ($isPython) {
    if (Get-Command pytest -ErrorAction SilentlyContinue) {
      Run-Step "Unit tests (pytest)" { pytest -q }
    } else {
      Log-Add "pytest not installed"
    }
  } else {
    Log-Add "No unit test runner detected"
  }

  # -------------------------
  # 3) Integration tests
  # -------------------------
  if (Test-Path "scripts/integration") {
    Run-Step "Integration tests (script)" { & "./scripts/integration" }
  } elseif ($isNode -and (Has-NpmScript "integration")) {
    Run-Step "Integration tests (npm)" { npm run integration }
  } else {
    Log-Add "No integration tests detected"
  }

  # -------------------------
  # 4) Build artifact
  # -------------------------
  if ($isDotnet) {
    Run-Step "Build (dotnet publish)" { dotnet publish -c Release -o ./publish }
  } elseif ($isNode) {
    if (Has-NpmScript "build") {
      Run-Step "Build (npm run build)" { npm run build --silent }
    } else {
      Log-Add "No npm build script detected"
    }
  } elseif ($isPython) {
    Log-Add "Python build step skipped (use packaging if needed)"
  } else {
    Log-Add "No build step for unknown project type"
  }

  # -------------------------
  # 5) E2E tests (Playwright/Cypress)
  # -------------------------
  $hasPlaywrightConfig = (Test-Path "playwright.config.js") -or (Test-Path "playwright.config.ts")
  $hasCypressConfig = (Test-Path "cypress.json") -or (Test-Path "cypress.config.js") -or (Test-Path "cypress.config.ts")

  if ($hasPlaywrightConfig) {
    if (Get-Command npx -ErrorAction SilentlyContinue) {
      $e2eMs = [int]$E2E_TIMEOUT_SECONDS * 1000
      Run-Step "E2E tests (Playwright)" { npx playwright test --timeout $e2eMs }
    } else {
      Log-Add "npx not available for Playwright"
    }
  } elseif ($hasCypressConfig) {
    if (Get-Command npx -ErrorAction SilentlyContinue) {
      Run-Step "E2E tests (Cypress)" { npx cypress run --headless }
    } else {
      Log-Add "npx not available for Cypress"
    }
  } else {
    Log-Add "No E2E framework detected"
  }

  # -------------------------
  # 6) Docker build and health check
  # -------------------------
  if (Get-Command docker -ErrorAction SilentlyContinue) {
    Run-Step "Docker build" { docker build -t $DOCKER_IMAGE . }

    $cid = $null
    try {
      $cid = (docker run -d -p 8080:80 $DOCKER_IMAGE).Trim()
      Start-Sleep -Seconds 6
      $health = Invoke-WebRequest -Uri $HEALTH_ENDPOINT -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
      Log-Add "Health endpoint status: $($health.StatusCode)"
      $summary.Add("Docker health check: $($health.StatusCode)")
    } catch {
      Log-Add "Docker health check failed: $($_.Exception.Message)"
      $failures.Add("Docker health check: $($_.Exception.Message)")
    } finally {
      if ($cid) {
        docker stop $cid | Out-Null
        docker rm $cid | Out-Null
      }
    }
  } else {
    Log-Add "Docker not available; skipping container verification"
  }

  # -------------------------
  # 7) Lightweight security scan (trivy/snyk)
  # -------------------------
  if (Get-Command trivy -ErrorAction SilentlyContinue) {
    Run-Step "Security scan (trivy fs)" { trivy fs --severity HIGH,CRITICAL --no-progress . }
  } elseif (Get-Command snyk -ErrorAction SilentlyContinue) {
    Run-Step "Security scan (snyk test)" {
      snyk test
      if ($LASTEXITCODE -ne 0) {
        throw "snyk reported issues (exit code $LASTEXITCODE)"
      }
    }
  } else {
    Log-Add "No security scanner (trivy/snyk) available; skipping security scan"
  }

  # -------------------------
  # 8) Performance smoke test (hey/wrk)
  # -------------------------
  $perfTool = $null
  if (Get-Command hey -ErrorAction SilentlyContinue) {
    $perfTool = "hey"
  } elseif (Get-Command wrk -ErrorAction SilentlyContinue) {
    $perfTool = "wrk"
  }

  if ($perfTool -eq "hey") {
    Run-Step "Perf smoke (hey)" { hey -z "${PERF_SMOKE_DURATION}s" -c $PERF_SMOKE_CONCURRENCY $HEALTH_ENDPOINT }
  } elseif ($perfTool -eq "wrk") {
    Run-Step "Perf smoke (wrk)" { wrk -t2 -c $PERF_SMOKE_CONCURRENCY -d "${PERF_SMOKE_DURATION}s" $HEALTH_ENDPOINT }
  } else {
    Log-Add "No perf tool (hey/wrk) available; skipping perf smoke"
  }

  # -------------------------
  # 9) Git integrity and repo size checks
  # -------------------------
  Run-Step "Git fsck" { git fsck --full }
  Run-Step "Git count-objects" { git count-objects -vH }

  # -------------------------
  # 10) Collect logs and append report
  # -------------------------
  $reportLines = @()
  $reportLines += "## MVP Test and Debug Run - $ts"
  $reportLines += ""
  $reportLines += "### Summary"
  foreach ($s in $summary) { $reportLines += "- $s" }

  if ($failures.Count -gt 0) {
    $reportLines += ""
    $reportLines += "### Failures"
    foreach ($f in $failures) { $reportLines += "- $f" }
    $reportLines += ""
    $reportLines += "Action: Investigate logs in docs/reports/logs and reproduce failing step locally."
  } else {
    $reportLines += ""
    $reportLines += "All checks passed."
  }

  $reportLines += ""
  $reportLines += "Logs: docs/reports/logs"
  $reportLines += ""

  if (-not (Test-Path $REPORT_FILE)) {
    "# Module 2 Remediation Report`n" | Out-File -FilePath $REPORT_FILE -Encoding utf8
  }
  Add-Content -Path $REPORT_FILE -Value ($reportLines -join "`n")
  Log-Add "Appended run summary to $REPORT_FILE"

  # -------------------------
  # 11) Optionally create GitHub issue for failures
  # -------------------------
  if ($failures.Count -gt 0 -and $GITHUB_PAT -and $GITHUB_PAT -ne "") {
    try {
      $body = "Automated MVP test run on $ts detected failures:`n`n"
      foreach ($f in $failures) { $body += "- $f`n" }
      $payload = @{ title = "Automated test failures - $ts"; body = $body } | ConvertTo-Json

      Invoke-RestMethod -Uri "https://api.github.com/repos/$OWNER_REPO/issues" -Method Post -Headers @{
        Authorization = "token $GITHUB_PAT"
        "User-Agent"  = "TFXHub-Automation"
        Accept        = "application/vnd.github+json"
      } -Body $payload -ContentType "application/json"

      Log-Add "Created GitHub issue for failures"
    } catch {
      Log-Add "Failed to create GitHub issue: $($_.Exception.Message)"
    }
  }

  # -------------------------
  # 12) Final output
  # -------------------------
  Log-Add "`n=== Run complete - $ts ==="
  if ($failures.Count -gt 0) {
    Write-Output "MVP test run completed with failures. See docs/reports/logs and $REPORT_FILE for details."
    Write-Output "Failures:"
    $failures | ForEach-Object { Write-Output " - $_" }
  } else {
    Write-Output "MVP test run completed successfully. Summary appended to $REPORT_FILE"
  }

  Write-Output "Logs directory: $LOG_DIR"
  Write-Output "Remediation report: $REPORT_FILE"
} finally {
  Pop-Location
}
