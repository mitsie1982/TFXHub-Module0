#!/usr/bin/env powershell
# .githooks/pre-commit.ps1 — Git pre-commit hook for validating WhatsApp templates
# 
# This hook is automatically executed by git before each commit if:
#   1. core.hooksPath is set to .githooks: git config core.hooksPath .githooks
#   2. PowerShell script execution is allowed in your environment
#
# Installation:
#   git config core.hooksPath .githooks
#
# Testing:
#   powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File .githooks/pre-commit.ps1

$hookDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $hookDir
$scriptPath = Join-Path (Join-Path $repoRoot "scripts") "pre-commit-whatsapp-validate.ps1"
& $scriptPath
