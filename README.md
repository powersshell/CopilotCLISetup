<p align="center">
  <img src="banner.png" alt="Copilot CLI Setup" width="800">
</p>

# Copilot CLI Setup Script

[![Test](https://github.com/powersshell/CopilotCLISetup/actions/workflows/test.yml/badge.svg)](https://github.com/powersshell/CopilotCLISetup/actions/workflows/test.yml)
[![Security Scan](https://github.com/powersshell/CopilotCLISetup/actions/workflows/security.yml/badge.svg)](https://github.com/powersshell/CopilotCLISetup/actions/workflows/security.yml)

A one-command setup script that installs and configures [GitHub Copilot CLI](https://docs.github.com/copilot/concepts/agents/about-copilot-cli) on your machine. Designed to make onboarding as frictionless as possible — just run it and follow the prompts.

## Quick Start

```powershell
# Clone and run (PowerShell 6+ / pwsh)
git clone https://github.com/powersshell/CopilotCLISetup.git
cd CopilotCLISetup
./Setup-CopilotCLI.ps1
```

Or run directly without cloning:

```powershell
irm https://raw.githubusercontent.com/powersshell/CopilotCLISetup/main/Setup-CopilotCLI.ps1 | iex
```

The script will walk you through everything interactively.

## What It Does

| Step | Description | Optional? |
|------|-------------|-----------|
| **1. Prerequisites** | Checks PowerShell version, internet connectivity, and available install tools | No |
| **2. Install Method** | Lets you choose: winget, npm, or direct install script | No |
| **3. Installation** | Installs Copilot CLI (or offers to update if already installed) | No |
| **4. VS Code Setup** | Installs VS Code and GitHub Copilot extensions (detects built-in extensions in VS Code 2025+) | ✅ Yes |
| **5. GitHub CLI** | Installs GitHub CLI (`gh`) for terminal-based GitHub workflows | ✅ Yes |
| **6. Custom Instructions** | Creates template instruction files to personalize Copilot behavior | ✅ Yes |
| **7. Authentication** | Launches Copilot CLI for interactive GitHub login — placed last so you won't get stuck mid-setup | ✅ Yes |
| **8. Summary** | Shows what was configured and helpful tips for getting started | No |

> **💡 Why is authentication last?** New users unfamiliar with Copilot CLI might not know to type `/exit` to return to the script. By placing login at the end, all configuration is already complete — if you stay in Copilot CLI, that's fine!

## Features

- 🚀 **One-command setup** — handles everything from install to configuration
- 🔄 **Idempotent** — safe to re-run; detects existing installs, skips or updates gracefully
- 🖥️ **Cross-platform** — works on Windows, macOS, and Linux
- 🎨 **Beautiful CLI** — colored output, ASCII banner, clear progress indicators
- 🛡️ **Secure** — never stores or asks for passwords/tokens directly
- 📝 **Custom instructions** — creates starter templates for personalizing Copilot
- 💻 **VS Code integration** — optionally installs VS Code + Copilot extensions
- 🐙 **GitHub CLI** — optionally installs `gh` for terminal-based GitHub workflows
- ⚡ **Smart updates** — detects when you're already on the latest version

## Prerequisites

- **PowerShell 6+** (PowerShell 7 recommended)
  - Windows: `winget install Microsoft.PowerShell`
  - macOS: `brew install powershell`
  - Linux: [Install instructions](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux)
- **Internet connection**
- **A GitHub account with an active Copilot subscription**
  - [See Copilot plans](https://github.com/features/copilot/plans)

You'll also need at least one of these install tools:
- `winget` (Windows 10/11 — usually pre-installed)
- `npm` (requires [Node.js](https://nodejs.org))
- `curl` (macOS/Linux — usually pre-installed)

## Options

| Parameter | Description |
|-----------|-------------|
| `-SkipInstructions` | Skip creating custom instruction template files |
| `-NonInteractive` | Accept all defaults without prompting (uses first available install method) |

### Examples

```powershell
# Standard interactive setup
./Setup-CopilotCLI.ps1

# Skip custom instructions setup
./Setup-CopilotCLI.ps1 -SkipInstructions

# Accept all defaults (CI/automation friendly)
./Setup-CopilotCLI.ps1 -NonInteractive
```

## What Gets Installed / Created

| Component | How | Notes |
|-----------|-----|-------|
| **Copilot CLI** | winget / npm / install script | Core install — always runs |
| **VS Code** | winget / brew / apt | Only if not already installed, user confirms |
| **GitHub Copilot extensions** | `code --install-extension` | Skipped if already built-in (VS Code 2025+) |
| **GitHub CLI (`gh`)** | winget / brew / apt | Only if user opts in (defaults to No) |
| **`~/.copilot/copilot-instructions.md`** | Created from template | User-level Copilot instructions |
| **`.github/copilot-instructions.md`** | Created from template | Repo-level instructions (only if in a git repo) |

## Troubleshooting

### "copilot" command not found after install
Close and reopen your terminal to refresh PATH, then try `copilot` again.

### "No available upgrade found" during update
This is normal — it means you're already on the latest version. The script handles this gracefully and continues.

### VS Code extension install shows "already available (built-in)"
VS Code 2025+ ships GitHub Copilot as a built-in extension. No separate install needed — you're all set!

### Running on Windows PowerShell 5.1
The script requires PowerShell 6+. Upgrade with:
```powershell
winget install Microsoft.PowerShell
```
Then launch `pwsh` instead of `powershell`.

### winget not available
On Windows, install the [App Installer](https://aka.ms/getwinget) from the Microsoft Store, or use npm as an alternative.

### Organization restrictions
If your organization manages Copilot access, an admin may need to enable Copilot CLI in your org settings. See [Managing policies for Copilot](https://docs.github.com/copilot/managing-copilot/managing-github-copilot-in-your-organization).

## After Setup

Once installed, launch Copilot CLI anytime with:
```
copilot
```

Helpful first commands inside the CLI:
- `/help` — see all available commands
- `/login` — authenticate with GitHub
- `/model` — choose your AI model
- `@filename` — reference files in your prompts
- `#123` — reference GitHub issues/PRs
- `/exit` — exit back to your terminal
- `/update` — update to the latest version

## Development

### Running Tests Locally

```powershell
# Install Pester
Install-Module -Name Pester -Force -Scope CurrentUser -MinimumVersion 5.0

# Run tests
Invoke-Pester ./tests -Output Detailed
```

### CI/CD

This repo uses GitHub Actions for:
- **Testing** — syntax validation, function structure checks, Pester unit tests, and dry-run execution across Windows/macOS/Linux
- **Security** — PSScriptAnalyzer linting and TruffleHog secret detection

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Ensure tests pass (`Invoke-Pester ./tests`)
4. Submit a pull request

## License

MIT — see [LICENSE](LICENSE) for details.
