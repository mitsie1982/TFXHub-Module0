<#
TFXHub: Package Demo for USB / Flash Drive
==========================================
Creates a self-contained bundle folder ready to copy onto any flash drive.

Usage (run from repo root):
  powershell -ExecutionPolicy Bypass -File scripts\package-demo.ps1
  
  # Copy directly to USB drive E:\:
  powershell -ExecutionPolicy Bypass -File scripts\package-demo.ps1 -Destination E:\TFXHub-Demo
#>

param(
  [string]$Destination = "",
  [string]$ImageTag = "tfxhub-demo:verify"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) { throw "Run this script from inside the git repository." }

$bundleDir = if ($Destination -ne "") { $Destination } else { Join-Path $repoRoot "demo-bundle" }

Write-Output ""
Write-Output "=== TFXHub Demo Packager ==="
Write-Output "Image  : $ImageTag"
Write-Output "Output : $bundleDir"
Write-Output ""

# ── Step 1: Verify image exists ──────────────────────────────────────────────
Write-Output "[1/5] Checking Docker image..."
$imgCheck = docker images $ImageTag --format "{{.ID}}" 2>$null
if (-not $imgCheck) {
  Write-Output "  Image '$ImageTag' not found. Building now..."
  docker build -t $ImageTag (Join-Path $repoRoot ".")
} else {
  Write-Output "  Found: $ImageTag ($imgCheck)"
}

# ── Step 2: Create bundle folder structure ───────────────────────────────────
Write-Output "[2/5] Creating bundle folder..."
$null = New-Item -ItemType Directory -Path $bundleDir -Force
$null = New-Item -ItemType Directory -Path (Join-Path $bundleDir "docs") -Force

# ── Step 3: Export Docker image to tar ───────────────────────────────────────
$tarPath = Join-Path $bundleDir "tfxhub-demo.tar"
Write-Output "[3/5] Exporting Docker image to tar (this takes ~30s)..."
docker save -o $tarPath $ImageTag
$sizeMB = [math]::Round((Get-Item $tarPath).Length / 1MB, 1)
Write-Output "  Saved: tfxhub-demo.tar ($sizeMB MB)"

# ── Step 4: Copy supporting files ────────────────────────────────────────────
Write-Output "[4/5] Copying docs and run scripts..."

# Docs
foreach ($f in @("README_DEMO.md","README.md","SECURITY.md")) {
  $src = Join-Path $repoRoot $f
  if (Test-Path $src) { Copy-Item $src (Join-Path $bundleDir "docs\") }
}
foreach ($f in @("QUICKSTART.md","EXECUTIVE_SUMMARY_MODULE2.md","COMMUNICATIONS.md","WHATSAPP_TEMPLATES.json")) {
  $src = Join-Path $repoRoot "docs\$f"
  if (Test-Path $src) { Copy-Item $src (Join-Path $bundleDir "docs\") }
}

# Windows run script
$winScript = @"
@echo off
REM === TFXHub Demo - Windows Quick Start ===
echo Loading TFXHub demo image into Docker...
docker load -i tfxhub-demo.tar
IF %ERRORLEVEL% NEQ 0 ( echo [ERROR] docker load failed. Is Docker Desktop running? & pause & exit /b 1 )

echo Starting TFXHub demo container on port 8080...
docker run -d -p 8080:80 --name tfxhub-demo tfxhub-demo:verify
IF %ERRORLEVEL% NEQ 0 ( echo [ERROR] Container failed to start. & pause & exit /b 1 )

echo.
echo Demo is running at: http://localhost:8080/api/health
echo.
echo To stop the demo, run:  stop-demo.bat
pause
"@
$winScript | Out-File -FilePath (Join-Path $bundleDir "start-demo.bat") -Encoding ascii

$stopScript = @"
@echo off
docker stop tfxhub-demo
docker rm tfxhub-demo
echo Demo stopped and container removed.
pause
"@
$stopScript | Out-File -FilePath (Join-Path $bundleDir "stop-demo.bat") -Encoding ascii

# PowerShell run script (cross-version compatible)
$psScript = @"
# TFXHub Demo - PowerShell Quick Start
Write-Output "Loading Docker image..."
docker load -i "`$PSScriptRoot\tfxhub-demo.tar"
if (`$LASTEXITCODE -ne 0) { Write-Error "docker load failed"; exit 1 }

Write-Output "Starting container on http://localhost:8080 ..."
docker run -d -p 8080:80 --name tfxhub-demo tfxhub-demo:verify
if (`$LASTEXITCODE -ne 0) { Write-Error "docker run failed"; exit 1 }

Start-Sleep -Seconds 5
try {
  `$r = Invoke-WebRequest -Uri http://localhost:8080/api/health -UseBasicParsing -TimeoutSec 10
  Write-Output "Health: `$(`$r.StatusCode) - `$(`$r.Content)"
} catch {
  Write-Warning "Container started but /api/health not responding: `$(`$_.Exception.Message)"
}

Write-Output ""
Write-Output "Demo running at: http://localhost:8080"
Write-Output "To stop:  docker stop tfxhub-demo; docker rm tfxhub-demo"
"@
$psScript | Out-File -FilePath (Join-Path $bundleDir "start-demo.ps1") -Encoding utf8

# Quick-start README on the flash root
$readmeContent = @"
# TFXHub MVP Demo

## Requirements
- Docker Desktop installed and running (https://docs.docker.com/get-docker/)
- 1 GB free RAM

## Windows Quick Start
1. Open Command Prompt or PowerShell in this folder
2. Run: start-demo.bat   (or: powershell -ExecutionPolicy Bypass -File start-demo.ps1)
3. Open: http://localhost:8080/api/health
4. When done: stop-demo.bat

## Manual Docker commands
    docker load -i tfxhub-demo.tar
    docker run -d -p 8080:80 --name tfxhub-demo tfxhub-demo:verify
    docker stop tfxhub-demo ; docker rm tfxhub-demo
    
## Included documentation
    docs\QUICKSTART.md
    docs\EXECUTIVE_SUMMARY_MODULE2.md
    docs\COMMUNICATIONS.md
    docs\WHATSAPP_TEMPLATES.json

Packaged: $(Get-Date -Format 'yyyy-MM-dd HH:mm') UTC
"@
$readmeContent | Out-File -FilePath (Join-Path $bundleDir "README.txt") -Encoding utf8

# ── Step 5: Summary ──────────────────────────────────────────────────────────
Write-Output "[5/5] Bundle complete."
Write-Output ""
$items = Get-ChildItem $bundleDir -Recurse -File
$totalMB = [math]::Round(($items | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
Write-Output "Bundle contents:"
$items | Select-Object @{N='File';E={$_.FullName.Replace($bundleDir+'\','')}}, @{N='MB';E={[math]::Round($_.Length/1MB,1)}} | Format-Table -AutoSize
Write-Output "Total bundle size: $totalMB MB"
Write-Output ""

if ($Destination -ne "") {
  Write-Output "Bundle written to: $Destination"
  Write-Output "Safely eject your flash drive when copy is complete."
} else {
  Write-Output "Bundle written to: $bundleDir"
  Write-Output ""
  Write-Output "Next: Insert flash drive, note its drive letter (e.g. E:), then run:"
  Write-Output "  powershell -ExecutionPolicy Bypass -File scripts\package-demo.ps1 -Destination E:\TFXHub-Demo"
}
