# Git Hooks Setup Guide

## Pre-Commit Hook: WhatsApp Templates Validation

This directory contains PowerShell scripts that can be installed as Git hooks to validate your commits.

### Installation

#### Option 1: Using .githooks directory (Recommended)

```powershell
# Configure git to use .githooks directory
git config core.hooksPath .githooks
```

#### Option 2: Manual installation to .git/hooks

```powershell
# Copy the validation script to .git/hooks
Copy-Item scripts/pre-commit-whatsapp-validate.ps1 .git/hooks/pre-commit

# Enable PowerShell script execution (if needed)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
```

#### Option 3: Using symlinks (Unix-style)

```bash
ln -s ../../scripts/pre-commit-whatsapp-validate.ps1 .git/hooks/pre-commit
```

### Testing Hooks Locally

Test the WhatsApp templates validation before committing:

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/pre-commit-whatsapp-validate.ps1
```

### What the Hooks Do

- **pre-commit-whatsapp-validate.ps1**: Validates that `docs/WHATSAPP_TEMPLATES.json` is valid JSON and contains all required audience templates (contractors, customers, admins, developers, owners).

### Troubleshooting

**Error: "running scripts is disabled on this system"**

Set the execution policy for your user:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or bypass it temporarily for a single command:
```powershell
powershell -ExecutionPolicy Bypass -File scripts/pre-commit-whatsapp-validate.ps1
```

**Git is not running the hook**

1. Verify the hook file is executable: `git ls-files --stage .githooks/pre-commit` (should show mode 100755)
2. Check git config: `git config core.hooksPath` (should show `.githooks` or `.git/hooks`)
3. Ensure PowerShell is available and accessible from git bash/cmd

## Contributing

When adding new audience types or templates to `docs/WHATSAPP_TEMPLATES.json`:

1. Add the template object with all required fields: `template_name`, `language`, `body`
2. Run the validation hook locally: `powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/pre-commit-whatsapp-validate.ps1`
3. Update `scripts/pre-commit-whatsapp-validate.ps1` to include the new audience in `$requiredFields` if it's a mandatory audience

