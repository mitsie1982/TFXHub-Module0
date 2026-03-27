Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# TFXHub Infrastructure Automation
$sshEmail = "1hansbrummer@gmail.com"
$tempRoot = git rev-parse --show-toplevel 2>$null
if ($tempRoot) { $repoRoot = $tempRoot } else { $repoRoot = (Get-Location).Path }
$logFile = Join-Path $repoRoot ".tfxhub_automation.log"

"`n=== TFX Hub Infrastructure Setup ===" | Tee-Object -FilePath $logFile

# 1. SSH Setup
Write-Output "`nStep 1: SSH Key Setup"
$sshDir = Join-Path $env:USERPROFILE ".ssh"
$keyPath = Join-Path $sshDir "id_ed25519"
$keyPubPath = "$keyPath.pub"
if (-not (Test-Path $keyPath)) {
  New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
  ssh-keygen -t ed25519 -C $sshEmail -f $keyPath -N ""
  "Generated SSH key at: $keyPath" | Add-Content -Path $logFile
}

if (Test-Path $keyPubPath) {
  Write-Output ""
  Write-Output "COPY THIS PUBLIC KEY TO GITHUB (Settings -> SSH and GPG keys):"
  Get-Content $keyPubPath
  Write-Output ""
}

Start-Service ssh-agent -ErrorAction SilentlyContinue
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
& ssh-add $keyPath 2>$null
$ErrorActionPreference = $prevEAP

# 2. Repository Setup
Write-Output "Step 2: Repository Verification"
Push-Location $repoRoot
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
git remote add origin "git@github.com:mitsie1982/TFXHub-Module0.git" 2>$null
$ErrorActionPreference = $prevEAP
git fsck --full 2>&1 | Out-Null
git gc --aggressive --prune=now 2>&1 | Out-Null
"Repo verified and GC complete" | Add-Content -Path $logFile
Pop-Location

# 3. Communications Artifacts
Write-Output "`nStep 3: Communications Artifacts"
$docsDir = Join-Path $repoRoot "docs"
$webDir = Join-Path (Join-Path $repoRoot "web") "snippets"
foreach ($d in @($docsDir, $webDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }

# Create COMMUNICATIONS.md
$commPath = Join-Path $docsDir "COMMUNICATIONS.md"
if (-not (Test-Path $commPath)) {
  @"
# Communications and Messaging Playbook

## Audiences
- Contractors: Formal, compliance-focused
- Customers: Friendly, service-focused
- Admins: Technical, operational
- Developers: Technical, collaborative
- Owners: Executive, strategic
- Demo Users: Friendly, exploratory
"@ > $commPath
  "Created COMMUNICATIONS.md" | Add-Content -Path $logFile
}

# Create WHATSAPP_TEMPLATES.json
$jsonPath = Join-Path $docsDir "WHATSAPP_TEMPLATES.json"
if (-not (Test-Path $jsonPath)) {
  $templates = @{
    contractors = @{template_name = "tfx_compliance_reminder"; language = "en_US"; body = "TFX: {name}, upload compliance docs"}
    customers = @{template_name = "tfx_service_update"; language = "en_US"; body = "TFX: Hi {name}, account active"}
    admins = @{template_name = "tfx_admin_alert"; language = "en_US"; body = "TFX: Admin {name}, status: {status}"}
    developers = @{template_name = "tfx_dev_notice"; language = "en_US"; body = "TFX: Dev {name}, pull latest"}
    owners = @{template_name = "tfx_exec_summary"; language = "en_US"; body = "TFX: Report: {report_link}"}
    demo_user = @{template_name = "tfx_demo_user"; language = "en_US"; body = "TFX: Try demo at {demo_link}"}
  }
  ConvertTo-Json $templates -Depth 10 > $jsonPath
  "Created WHATSAPP_TEMPLATES.json" | Add-Content -Path $logFile
}

# Create banner and modal snippets
$bannerPath = Join-Path $webDir "banners.html"
if (-not (Test-Path $bannerPath)) {
  "<div id='tfx-banner-demo' class='banner' style='display:none;'>Try the TFX Demo</div>" > $bannerPath
  "Created banners.html" | Add-Content -Path $logFile
}

$modalPath = Join-Path $webDir "modals.html"
if (-not (Test-Path $modalPath)) {
  "<template id='tfx-modal-demo'><div><h2>Try Demo</h2><button>Start</button></div></template>" > $modalPath
  "Created modals.html" | Add-Content -Path $logFile
}

$jsPath = Join-Path $webDir "banner-inject.js"
if (-not (Test-Path $jsPath)) {
  "(function(){const role=window.TFX?.currentUser?.role||'guest';const el=document.getElementById('tfx-banner-'+role);if(el)el.style.display='block';})();" > $jsPath
  "Created banner-inject.js" | Add-Content -Path $logFile
}

# 4. Pre-commit Hook
Write-Output "Step 4: Git Hooks Setup"
$hooksDir = Join-Path $repoRoot ".githooks"
if (-not (Test-Path $hooksDir)) { New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null }

$hookPath = Join-Path $hooksDir "pre-commit"
$hookContent = @'
#!/bin/sh
SCRIPT="scripts/pre-commit-whatsapp-validate.ps1"
if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT"
  exit $?
fi
if command -v powershell >/dev/null 2>&1; then
  powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT"
  exit $?
fi
echo "PowerShell not found" >&2; exit 1
'@
$hookContent > $hookPath
git update-index --chmod=+x $hookPath 2>$null
git config core.hooksPath .githooks 2>$null
"Created pre-commit hook" | Add-Content -Path $logFile

# 5. Demo Documentation
Write-Output "Step 5: Demo Documentation"
$demoDoc = Join-Path $repoRoot "README_DEMO.md"
if (-not (Test-Path $demoDoc)) {
  @"
# Demo Artifact - TFX Hub

## Quick Start
docker load -i tfxhub-demo.tar
docker run -d -p 8080:80 --name tfxhub-demo tfxhub-demo:latest
open http://localhost:8080

## Stop
docker stop tfxhub-demo && docker rm tfxhub-demo

Generated: $(Get-Date -Format o)
"@ > $demoDoc
  "Created README_DEMO.md" | Add-Content -Path $logFile
}

# 6. Stage Changes
Write-Output "`nStep 6: Staging Changes"
Push-Location $repoRoot
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
git add "docs/COMMUNICATIONS.md" "docs/WHATSAPP_TEMPLATES.json" "web/snippets/banners.html" "web/snippets/modals.html" "web/snippets/banner-inject.js" ".githooks/pre-commit" "README_DEMO.md" 2>$null
$ErrorActionPreference = $prevEAP
$status = git status --short
if ($status) {
  Write-Output "Files staged. Review with: git status"
}
Pop-Location

# Summary
Write-Output "`n=== SETUP COMPLETE ==="
Write-Output ""
Write-Output "Next Steps:"
Write-Output "1. Add SSH public key to https://github.com/settings/keys"
Write-Output "2. Verify: ssh -T git@github.com"
Write-Output "3. Review: git status"
Write-Output "4. Commit: git commit -m 'chore: add communications and hooks'"
Write-Output "5. Push: git push origin master"
Write-Output ""
Write-Output "Log: $logFile"
"Setup completed at $(Get-Date -Format o)" | Add-Content -Path $logFile
