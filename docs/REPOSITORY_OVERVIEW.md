# TFXHub Repository Overview

**Repository root**
- Path: `C:\Users\1hans`

**Repository structure**
- src/TFXHub.Host  ; ASP.NET Core Host project
- src/TFXHub.Agent ; Background agent/service
- src/TFXHub.Client ; CLI or client app
- tests/           ; Unit and integration tests (if present)
- docs/            ; Documentation and remediation reports
- docker-compose.yml ; Optional container orchestration

**Clone instructions**
- SSH (recommended for developers):
  - `git clone git@github.com:Hans-TFX/TFXHub.git`
- HTTPS:
  - `git clone https://github.com/Hans-TFX/TFXHub.git`

**VS Code setup**
- Recommended extensions:
  - **C#** (ms-dotnettools.csharp)
  - **GitLens** (eamodio.gitlens)
  - **Docker** (ms-azuretools.vscode-docker)
  - **EditorConfig for VS Code** (EditorConfig.EditorConfig)
  - **GitHub Copilot** (GitHub.copilot) — optional, requires sign-in
  - **.NET Install Tool for Extension Authors** if needed
- Open repository:
  - File → Open Folder → select repository root
  - Use Command Palette `Ctrl+Shift+P` → `Developer: Reload Window` if extensions were just installed

**Running solutions and projects**
- Restore and build:
  - `dotnet restore`
  - `dotnet build --no-restore`
- Run Host locally:
  - `dotnet run --project src/TFXHub.Host`
- Run Agent locally:
  - `dotnet run --project src/TFXHub.Agent`
- Run Client CLI:
  - `dotnet run --project src/TFXHub.Client -- <args>`

**Terminal usage and REPL**
- Use integrated terminal: View -> Terminal or `Ctrl+`
- Start C# interactive REPL:
  - `dotnet repl` (if installed) or use `csi` for C# scripting
- Python files:
  - `python -m venv .venv`
  - `.\.venv\Scripts\Activate`
  - `python script.py`
- Use `pwsh` profile for PowerShell Core if preferred

**AI assistant integration GitHub Copilot**
- Install GitHub Copilot extension in VS Code
- Sign in via the extension prompt (GitHub account required)
- Enable Copilot suggestions in settings
- Use Copilot in editor with `Alt+Enter` or inline suggestions

**Notes and next steps**
- Ensure SSH key is added to GitHub and ssh-agent is running before pushing.
- Replace remote URLs above if your org or repo name differs.
