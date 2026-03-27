#!/usr/bin/env powershell
# pre-commit hook: validate docs/WHATSAPP_TEMPLATES.json
# 
# INSTALLATION:
#   Windows: Copy or symlink this script to .git/hooks/pre-commit (no extension)
#   Then enable execution: Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
#   Or run git with: git config core.hooksPath .githooks (if using .githooks directory)
#
# TESTING:
#   powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/pre-commit-whatsapp-validate.ps1

Write-Host "Running pre-commit hook: validating WhatsApp templates JSON..." -ForegroundColor Cyan

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    Write-Error "Not inside a git repository."
    exit 1
}

$jsonPath = Join-Path $repoRoot "docs\WHATSAPP_TEMPLATES.json"

if (-not (Test-Path $jsonPath)) {
    Write-Host "[INFO] No WhatsApp templates file found at $jsonPath. Skipping validation." -ForegroundColor Yellow
    exit 0
}

try {
    $content = Get-Content $jsonPath -Raw
    $parsed = $content | ConvertFrom-Json -ErrorAction Stop
    
    # Verify required fields
    $requiredFields = @("contractors", "customers", "admins", "developers", "owners")
    $missingFields = @()
    
    foreach ($field in $requiredFields) {
        if (-not $parsed.PSObject.Properties[$field]) {
            $missingFields += $field
        }
    }
    
    if ($missingFields) {
        Write-Error "[ERROR] Missing required templates: $($missingFields -join ', ')"
        exit 1
    }
    
    Write-Host "[OK] $jsonPath is valid JSON with all required templates." -ForegroundColor Green
    exit 0
}
catch {
    Write-Error "[ERROR] Invalid JSON in $jsonPath"
    Write-Error $_.Exception.Message
    Write-Error "Commit aborted. Please fix the JSON before committing them."
    exit 1
}
