<#
.SYNOPSIS
    Sets up GitHub Copilot CLI on your machine.

.DESCRIPTION
    Interactive PowerShell script that installs and configures GitHub Copilot CLI.
    Checks prerequisites, installs the CLI via your preferred method (winget, npm, or
    direct download), guides you through authentication, and optionally creates
    custom instruction template files.

    Safe to re-run — detects existing installations and skips/updates gracefully.

.NOTES
    Requires PowerShell 6+ on Windows. Works on Windows, macOS, and Linux.
    See README.md for more details.

.LINK
    https://docs.github.com/copilot/concepts/agents/about-copilot-cli
#>

[CmdletBinding()]
param(
    [switch]$SkipInstructions,
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region ═══════════════════════════════════════════════════════════════════════════
# HELPERS
#region ═══════════════════════════════════════════════════════════════════════════

function Write-Banner {
    $banner = @"

   ██████╗ ██████╗ ██████╗ ██╗██╗      ██████╗ ████████╗     ██████╗██╗     ██╗
  ██╔════╝██╔═══██╗██╔══██╗██║██║     ██╔═══██╗╚══██╔══╝    ██╔════╝██║     ██║
  ██║     ██║   ██║██████╔╝██║██║     ██║   ██║   ██║       ██║     ██║     ██║
  ██║     ██║   ██║██╔═══╝ ██║██║     ██║   ██║   ██║       ██║     ██║     ██║
  ╚██████╗╚██████╔╝██║     ██║███████╗╚██████╔╝   ██║       ╚██████╗███████╗██║
   ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝ ╚═════╝    ╚═╝        ╚═════╝╚══════╝╚═╝

"@
    Write-Host $banner -ForegroundColor Cyan
    Write-Host "  GitHub Copilot CLI Setup" -ForegroundColor White
    Write-Host "  ────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "  ▶ " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-SubStep {
    param([string]$Message)
    Write-Host "    • " -ForegroundColor DarkGray -NoNewline
    Write-Host $Message -ForegroundColor Gray
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✓ " -ForegroundColor Green -NoNewline
    Write-Host $Message -ForegroundColor Green
}

function Write-Warning2 {
    param([string]$Message)
    Write-Host "  ⚠ " -ForegroundColor Yellow -NoNewline
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Error2 {
    param([string]$Message)
    Write-Host "  ✗ " -ForegroundColor Red -NoNewline
    Write-Host $Message -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "  ℹ " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-SectionHeader {
    param([string]$Title, [int]$Number)
    Write-Host ""
    Write-Host "  [$Number] $Title" -ForegroundColor Cyan
    Write-Host "  ────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-UserChoice {
    param(
        [string]$Prompt,
        [string[]]$Options,
        [int]$Default = 0
    )

    Write-Host ""
    Write-Host "  $Prompt" -ForegroundColor White
    for ($i = 0; $i -lt $Options.Length; $i++) {
        $marker = if ($i -eq $Default) { " (default)" } else { "" }
        Write-Host "    [$($i + 1)] $($Options[$i])$marker" -ForegroundColor Gray
    }
    Write-Host ""

    if ($NonInteractive) {
        return $Default
    }

    do {
        Write-Host "  Enter choice [1-$($Options.Length)]: " -ForegroundColor White -NoNewline
        $input_val = Read-Host
        if ([string]::IsNullOrWhiteSpace($input_val)) {
            return $Default
        }
        $choice = 0
        if ([int]::TryParse($input_val, [ref]$choice) -and $choice -ge 1 -and $choice -le $Options.Length) {
            return ($choice - 1)
        }
        Write-Host "    Invalid choice. Please enter a number between 1 and $($Options.Length)." -ForegroundColor Red
    } while ($true)
}

function Get-UserConfirmation {
    param([string]$Prompt, [bool]$Default = $true)

    if ($NonInteractive) { return $Default }

    $hint = if ($Default) { "[Y/n]" } else { "[y/N]" }
    Write-Host "  $Prompt $hint " -ForegroundColor White -NoNewline
    $response = Read-Host

    if ([string]::IsNullOrWhiteSpace($response)) {
        return $Default
    }
    return $response -match '^[Yy]'
}

function Refresh-PathEnv {
    # Reload PATH from registry (Windows only)
    if ($IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -eq 'Windows_NT')) {
        $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
        $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
        $env:Path = "$machinePath;$userPath"
    }
}

#endregion

#region ═══════════════════════════════════════════════════════════════════════════
# SECTION 1: PREREQUISITES
#region ═══════════════════════════════════════════════════════════════════════════

function Test-Prerequisites {
    Write-SectionHeader "Checking Prerequisites" 1

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-Step "PowerShell version: $psVersion"

    $runningOnWindows = $IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and $env:OS -eq 'Windows_NT')

    if ($runningOnWindows -and $psVersion.Major -lt 6) {
        Write-Error2 "Copilot CLI requires PowerShell 6+ on Windows."
        Write-Info "You are running Windows PowerShell $psVersion."
        Write-Info "Install PowerShell 7+: https://aka.ms/install-powershell"
        Write-Info "  Or run:  winget install Microsoft.PowerShell"
        Write-Host ""
        throw "PowerShell 6+ is required. Please upgrade and re-run this script."
    }
    Write-Success "PowerShell version OK"

    # Detect OS
    $script:Platform = if ($IsWindows) { 'Windows' }
                       elseif ($IsMacOS) { 'macOS' }
                       elseif ($IsLinux) { 'Linux' }
                       else { 'Unknown' }
    Write-Step "Platform: $script:Platform"

    # Check internet connectivity
    Write-Step "Checking internet connectivity..."
    try {
        $null = Invoke-WebRequest -Uri 'https://github.com' -UseBasicParsing -TimeoutSec 10 -Method Head
        Write-Success "Internet connection OK"
    }
    catch {
        Write-Error2 "Cannot reach github.com. Please check your internet connection."
        throw "Internet connectivity required."
    }

    # Check available install tools
    $script:HasWinget = Test-CommandExists 'winget'
    $script:HasNpm = Test-CommandExists 'npm'
    $script:HasCurl = Test-CommandExists 'curl'

    Write-Step "Available install tools:"
    if ($script:HasWinget) { Write-SubStep "winget ✓" } else { Write-SubStep "winget ✗" }
    if ($script:HasNpm) { Write-SubStep "npm ✓" } else { Write-SubStep "npm ✗" }
    if ($script:HasCurl) { Write-SubStep "curl ✓" } else { Write-SubStep "curl ✗" }

    Write-Host ""
    Write-Success "Prerequisites check complete"
}

#endregion

#region ═══════════════════════════════════════════════════════════════════════════
# SECTION 2: INSTALL METHOD SELECTION
#region ═══════════════════════════════════════════════════════════════════════════

function Select-InstallMethod {
    Write-SectionHeader "Select Installation Method" 2

    $options = @()
    $methods = @()

    if ($script:HasWinget -and $script:Platform -eq 'Windows') {
        $options += "winget (Windows package manager — recommended)"
        $methods += 'winget'
    }
    if ($script:HasNpm) {
        $options += "npm (Node.js — cross-platform)"
        $methods += 'npm'
    }
    if ($script:Platform -ne 'Windows') {
        $options += "Install script (curl — macOS/Linux)"
        $methods += 'script'
    }

    if ($options.Length -eq 0) {
        Write-Error2 "No supported installation method found!"
        Write-Info "Please install one of the following first:"
        if ($script:Platform -eq 'Windows') {
            Write-Info "  • winget: https://aka.ms/getwinget"
        }
        Write-Info "  • Node.js (includes npm): https://nodejs.org"
        if ($script:Platform -ne 'Windows') {
            Write-Info "  • curl: usually pre-installed on macOS/Linux"
        }
        throw "No installation method available."
    }

    $choice = Get-UserChoice -Prompt "How would you like to install Copilot CLI?" -Options $options -Default 0
    $script:InstallMethod = $methods[$choice]
    Write-Success "Selected: $($options[$choice])"
}

#endregion

#region ═══════════════════════════════════════════════════════════════════════════
# SECTION 3: INSTALL COPILOT CLI
#region ═══════════════════════════════════════════════════════════════════════════

function Install-CopilotCLI {
    Write-SectionHeader "Installing Copilot CLI" 3

    # Check if already installed
    $existingCopilot = Get-Command 'copilot' -ErrorAction SilentlyContinue
    if ($existingCopilot) {
        Write-Step "Copilot CLI is already installed!"
        Write-SubStep "Location: $($existingCopilot.Source)"

        # Try to get version
        try {
            $versionOutput = & copilot --version 2>&1
            Write-SubStep "Version: $versionOutput"
        }
        catch {
            Write-SubStep "Version: (could not determine)"
        }

        if (Get-UserConfirmation -Prompt "Would you like to update to the latest version?") {
            Write-Step "Updating Copilot CLI..."
            Invoke-InstallCommand -Update
        }
        else {
            Write-Success "Keeping current installation"
            return
        }
    }
    else {
        Write-Step "Installing Copilot CLI via $($script:InstallMethod)..."
        Invoke-InstallCommand
    }

    # Refresh PATH and verify
    Refresh-PathEnv
    Start-Sleep -Seconds 2

    if (-not (Test-CommandExists 'copilot')) {
        Write-Warning2 "The 'copilot' command is not yet available in this session."
        Write-Info "This usually means your PATH needs to be refreshed."
        if ($script:Platform -eq 'Windows') {
            Write-Info "Please close and reopen your terminal, then re-run this script."
            Write-Info "The installation itself likely succeeded."
        }
        else {
            Write-Info "Try running: source ~/.bashrc  (or ~/.zshrc)"
        }

        if (-not (Get-UserConfirmation -Prompt "Continue anyway? (Choose Yes if you just need to restart your terminal later)")) {
            throw "Copilot CLI not found on PATH. Please restart your terminal and try again."
        }
    }
    else {
        $versionOutput = & copilot --version 2>&1
        Write-Success "Copilot CLI installed successfully! Version: $versionOutput"
    }
}

function Invoke-InstallCommand {
    param([switch]$Update)

    switch ($script:InstallMethod) {
        'winget' {
            if ($Update) {
                & winget upgrade GitHub.Copilot --accept-source-agreements --accept-package-agreements
            }
            else {
                & winget install GitHub.Copilot --accept-source-agreements --accept-package-agreements
            }
        }
        'npm' {
            & npm install -g @github/copilot
        }
        'script' {
            if ($script:HasCurl) {
                & bash -c 'curl -fsSL https://gh.io/copilot-install | bash'
            }
            else {
                & bash -c 'wget -qO- https://gh.io/copilot-install | bash'
            }
        }
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error2 "Installation command failed with exit code $LASTEXITCODE."
        throw "Installation failed. Please check the output above for details."
    }
}

#endregion

#region ═══════════════════════════════════════════════════════════════════════════
# SECTION 4: AUTHENTICATION
#region ═══════════════════════════════════════════════════════════════════════════

function Start-Authentication {
    Write-SectionHeader "Authentication" 4

    Write-Step "Copilot CLI uses your GitHub account for authentication."
    Write-Host ""
    Write-Info "To log in, you'll need to:"
    Write-SubStep "1. Launch Copilot CLI by typing: copilot"
    Write-SubStep "2. Type /login and press Enter"
    Write-SubStep "3. Follow the browser-based authentication flow"
    Write-SubStep "4. Return here once you've logged in successfully"
    Write-Host ""

    Write-Info "Prerequisites for authentication:"
    Write-SubStep "An active GitHub Copilot subscription (individual, business, or enterprise)"
    Write-SubStep "See plans: https://github.com/features/copilot/plans"
    Write-Host ""

    if (-not (Test-CommandExists 'copilot')) {
        Write-Warning2 "Cannot launch copilot (not on PATH in this session)."
        Write-Info "After restarting your terminal, run 'copilot' and type '/login'."
        return
    }

    if (Get-UserConfirmation -Prompt "Would you like to launch Copilot CLI now to authenticate?") {
        Write-Host ""
        Write-Info "Launching Copilot CLI... Type /login to authenticate."
        Write-Info "When done, type /exit to return to this setup script."
        Write-Host ""
        Write-Host "  ────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

        try {
            & copilot
        }
        catch {
            Write-Warning2 "Copilot CLI exited. Continuing setup..."
        }

        Write-Host "  ────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
        Write-Success "Authentication step complete"
    }
    else {
        Write-Info "Skipping authentication for now."
        Write-Info "Remember to run 'copilot' and type '/login' before first use."
    }
}

#endregion

#region ═══════════════════════════════════════════════════════════════════════════
# SECTION 5: VS CODE SETUP
#region ═══════════════════════════════════════════════════════════════════════════

function Install-VSCodeSetup {
    Write-SectionHeader "VS Code Setup" 5

    Write-Step "VS Code pairs great with Copilot CLI for a complete AI-powered workflow."
    Write-Host ""

    # Check if VS Code is already installed
    $codeCmd = Get-Command 'code' -ErrorAction SilentlyContinue
    $vsCodeInstalled = $null -ne $codeCmd

    if ($vsCodeInstalled) {
        Write-Success "VS Code is already installed: $($codeCmd.Source)"
    }
    else {
        if (-not (Get-UserConfirmation -Prompt "Would you like to install Visual Studio Code?")) {
            Write-Info "Skipping VS Code setup."
            return
        }

        Write-Step "Installing VS Code..."
        switch ($script:Platform) {
            'Windows' {
                if ($script:HasWinget) {
                    & winget install Microsoft.VisualStudioCode --accept-source-agreements --accept-package-agreements
                }
                else {
                    Write-Warning2 "winget not available. Please install VS Code manually:"
                    Write-Info "  https://code.visualstudio.com/download"
                    return
                }
            }
            'macOS' {
                if (Test-CommandExists 'brew') {
                    & brew install --cask visual-studio-code
                }
                else {
                    Write-Warning2 "Homebrew not available. Please install VS Code manually:"
                    Write-Info "  https://code.visualstudio.com/download"
                    return
                }
            }
            'Linux' {
                if (Test-CommandExists 'snap') {
                    & snap install code --classic
                }
                elseif (Test-CommandExists 'apt') {
                    Write-Info "Installing via apt (may require sudo)..."
                    & sudo apt update
                    & sudo apt install -y code
                }
                else {
                    Write-Warning2 "Could not detect a supported package manager."
                    Write-Info "Please install VS Code manually: https://code.visualstudio.com/download"
                    return
                }
            }
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Warning2 "VS Code installation may have encountered issues."
            Write-Info "You can install it manually: https://code.visualstudio.com/download"
            return
        }

        # Refresh PATH
        Refresh-PathEnv
        Start-Sleep -Seconds 2

        if (Test-CommandExists 'code') {
            Write-Success "VS Code installed successfully!"
            $vsCodeInstalled = $true
        }
        else {
            Write-Warning2 "VS Code installed but 'code' command not on PATH yet."
            Write-Info "Restart your terminal, then run 'code' to verify."
            return
        }
    }

    # Offer to install Copilot extensions
    if ($vsCodeInstalled -and (Test-CommandExists 'code')) {
        Write-Host ""
        Write-Step "GitHub Copilot extensions for VS Code:"
        Write-SubStep "GitHub Copilot — AI code completions and suggestions"
        Write-SubStep "GitHub Copilot Chat — conversational AI within the editor"
        Write-Host ""

        if (Get-UserConfirmation -Prompt "Install GitHub Copilot extensions for VS Code?") {
            Write-Step "Installing extensions..."

            # Check which are already installed
            $installedExtensions = & code --list-extensions 2>&1

            $extensions = @(
                @{ Id = 'GitHub.copilot'; Name = 'GitHub Copilot' }
                @{ Id = 'GitHub.copilot-chat'; Name = 'GitHub Copilot Chat' }
            )

            foreach ($ext in $extensions) {
                if ($installedExtensions -contains $ext.Id) {
                    Write-SubStep "$($ext.Name) — already installed ✓"
                }
                else {
                    Write-SubStep "Installing $($ext.Name)..."
                    & code --install-extension $ext.Id --force 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-SubStep "$($ext.Name) — installed ✓"
                    }
                    else {
                        Write-Warning2 "Failed to install $($ext.Name). Install manually from the Extensions panel."
                    }
                }
            }

            Write-Host ""
            Write-Success "VS Code extensions configured!"
            Write-Info "Open VS Code and sign in to GitHub when prompted to activate Copilot."
        }
        else {
            Write-Info "Skipping extension installation."
            Write-Info "You can install them later from the VS Code Extensions panel."
        }
    }
}

#endregion

#region ═══════════════════════════════════════════════════════════════════════════
# SECTION 6: GITHUB CLI
#region ═══════════════════════════════════════════════════════════════════════════

function Install-GitHubCLI {
    Write-SectionHeader "GitHub CLI (optional)" 6

    Write-Step "GitHub CLI (gh) enhances your workflow with GitHub from the terminal."
    Write-SubStep "Create PRs, manage issues, run Actions, and more — all from the command line."
    Write-Host ""

    # Check if already installed
    $ghCmd = Get-Command 'gh' -ErrorAction SilentlyContinue
    if ($ghCmd) {
        $ghVersion = & gh --version 2>&1 | Select-Object -First 1
        Write-Success "GitHub CLI is already installed: $ghVersion"
        return
    }

    if (-not (Get-UserConfirmation -Prompt "Would you like to install GitHub CLI (gh)?" -Default $false)) {
        Write-Info "Skipping GitHub CLI installation."
        Write-Info "You can install it later: https://cli.github.com"
        return
    }

    Write-Step "Installing GitHub CLI..."
    switch ($script:Platform) {
        'Windows' {
            if ($script:HasWinget) {
                & winget install GitHub.cli --accept-source-agreements --accept-package-agreements
            }
            else {
                Write-Warning2 "winget not available. Please install GitHub CLI manually:"
                Write-Info "  https://cli.github.com"
                return
            }
        }
        'macOS' {
            if (Test-CommandExists 'brew') {
                & brew install gh
            }
            else {
                Write-Warning2 "Homebrew not available. Please install GitHub CLI manually:"
                Write-Info "  https://cli.github.com"
                return
            }
        }
        'Linux' {
            if (Test-CommandExists 'apt') {
                Write-Info "Installing via apt (may require sudo)..."
                & sudo apt update
                & sudo apt install -y gh
            }
            elseif (Test-CommandExists 'dnf') {
                & sudo dnf install -y gh
            }
            else {
                Write-Warning2 "Could not detect a supported package manager."
                Write-Info "Please install GitHub CLI manually: https://cli.github.com"
                return
            }
        }
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Warning2 "GitHub CLI installation may have encountered issues."
        Write-Info "You can install it manually: https://cli.github.com"
        return
    }

    # Refresh PATH and verify
    Refresh-PathEnv
    Start-Sleep -Seconds 2

    if (Test-CommandExists 'gh') {
        $ghVersion = & gh --version 2>&1 | Select-Object -First 1
        Write-Success "GitHub CLI installed: $ghVersion"
        Write-Host ""
        Write-Info "To authenticate, run:  gh auth login"
    }
    else {
        Write-Warning2 "GitHub CLI installed but 'gh' not on PATH yet."
        Write-Info "Restart your terminal, then run:  gh auth login"
    }
}

#endregion

#region ═══════════════════════════════════════════════════════════════════════════
# SECTION 7: CUSTOM INSTRUCTIONS
#region ═══════════════════════════════════════════════════════════════════════════

function Set-CustomInstructions {
    if ($SkipInstructions) { return }

    Write-SectionHeader "Custom Instructions" 7

    Write-Step "Custom instructions let you personalize Copilot's behavior."
    Write-Info "Copilot reads instructions from files like copilot-instructions.md"
    Write-Host ""

    # User-level instructions
    $userInstructionsDir = Join-Path $HOME '.copilot'
    $userInstructionsFile = Join-Path $userInstructionsDir 'copilot-instructions.md'

    if (Test-Path $userInstructionsFile) {
        Write-SubStep "User-level instructions already exist: $userInstructionsFile"
    }
    else {
        if (Get-UserConfirmation -Prompt "Create a user-level custom instructions template?") {
            if (-not (Test-Path $userInstructionsDir)) {
                New-Item -ItemType Directory -Path $userInstructionsDir -Force | Out-Null
            }

            $template = @"
# Copilot CLI Custom Instructions

<!-- These instructions apply to all your Copilot CLI sessions. -->
<!-- Edit this file to customize how Copilot behaves for you. -->

## About Me
<!-- Tell Copilot about your role, tech stack, and preferences. Examples: -->
<!-- - I'm a backend developer working primarily with C# and .NET -->
<!-- - I prefer concise responses with code examples -->
<!-- - I work on Azure-hosted services -->

## Coding Preferences
<!-- Examples: -->
<!-- - Use async/await patterns where possible -->
<!-- - Prefer explicit types over var/auto -->
<!-- - Always include error handling -->
<!-- - Follow Microsoft coding conventions -->

## Project Context
<!-- Examples: -->
<!-- - Our team uses GitHub Flow branching strategy -->
<!-- - We deploy to Azure Kubernetes Service -->
<!-- - Our APIs follow REST conventions with OpenAPI specs -->
"@
            Set-Content -Path $userInstructionsFile -Value $template -Encoding UTF8
            Write-Success "Created: $userInstructionsFile"
            Write-Info "Edit this file to customize Copilot's behavior globally."
        }
    }

    # Repo-level instructions (if in a git repo)
    $gitRoot = $null
    try {
        $gitRoot = & git rev-parse --show-toplevel 2>$null
    }
    catch { }

    if ($gitRoot) {
        $repoInstructionsDir = Join-Path $gitRoot '.github'
        $repoInstructionsFile = Join-Path $repoInstructionsDir 'copilot-instructions.md'

        if (Test-Path $repoInstructionsFile) {
            Write-SubStep "Repo-level instructions already exist: $repoInstructionsFile"
        }
        else {
            Write-Host ""
            Write-Info "You're in a git repository: $gitRoot"
            if (Get-UserConfirmation -Prompt "Create repo-level instructions (.github/copilot-instructions.md)?") {
                if (-not (Test-Path $repoInstructionsDir)) {
                    New-Item -ItemType Directory -Path $repoInstructionsDir -Force | Out-Null
                }

                $repoTemplate = @"
# Copilot Instructions for This Repository

<!-- These instructions apply to anyone using Copilot CLI in this repository. -->
<!-- Commit this file so your whole team benefits. -->

## Project Overview
<!-- Describe what this project does, its architecture, and key technologies. -->

## Development Guidelines
<!-- Include coding standards, patterns, and practices for this repo. -->

## Important Context
<!-- Mention anything Copilot should know: deployment targets, CI/CD, testing strategy, etc. -->
"@
                Set-Content -Path $repoInstructionsFile -Value $repoTemplate -Encoding UTF8
                Write-Success "Created: $repoInstructionsFile"
                Write-Info "Commit this file to share instructions with your team."
            }
        }
    }
}

#endregion

#region ═══════════════════════════════════════════════════════════════════════════
# SECTION 8: VALIDATION & SUMMARY
#region ═══════════════════════════════════════════════════════════════════════════

function Show-Summary {
    Write-SectionHeader "Setup Complete!" 8

    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║          GitHub Copilot CLI is ready to use!                 ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

    # Show what was done
    Write-Step "Summary of what was configured:"
    Write-SubStep "Install method: $($script:InstallMethod)"

    if (Test-CommandExists 'copilot') {
        $ver = & copilot --version 2>&1
        Write-SubStep "Copilot CLI version: $ver"
    }
    else {
        Write-SubStep "Copilot CLI installed (restart terminal to use)"
    }

    $userInstructionsFile = Join-Path $HOME '.copilot' 'copilot-instructions.md'
    if (Test-Path $userInstructionsFile) {
        Write-SubStep "User instructions: $userInstructionsFile"
    }

    if (Test-CommandExists 'code') {
        Write-SubStep "VS Code: installed ✓"
    }

    if (Test-CommandExists 'gh') {
        Write-SubStep "GitHub CLI: installed ✓"
    }

    Write-Host ""
    Write-Step "Getting started:"
    Write-SubStep "Launch:      copilot"
    Write-SubStep "Login:       /login  (if not already done)"
    Write-SubStep "Get help:    /help"
    Write-SubStep "Pick model:  /model"
    Write-SubStep "Exit:        /exit  or Ctrl+D"
    Write-Host ""

    Write-Step "Useful tips:"
    Write-SubStep "Use @ to reference files:       @src/main.ts"
    Write-SubStep "Use # to reference issues:      #42"
    Write-SubStep "Use ! to run shell commands:    !npm test"
    Write-SubStep "Use Shift+Tab to switch modes"
    Write-Host ""

    Write-Step "Learn more:"
    Write-SubStep "Docs:      https://docs.github.com/copilot/concepts/agents/about-copilot-cli"
    Write-SubStep "Feedback:  /feedback (from within Copilot CLI)"
    Write-SubStep "Updates:   /update  (from within Copilot CLI)"
    Write-Host ""
}

#endregion

#region ═══════════════════════════════════════════════════════════════════════════
# MAIN
#region ═══════════════════════════════════════════════════════════════════════════

try {
    Clear-Host
    Write-Banner
    Test-Prerequisites
    Select-InstallMethod
    Install-CopilotCLI
    Start-Authentication
    Install-VSCodeSetup
    Install-GitHubCLI
    Set-CustomInstructions
    Show-Summary
}
catch {
    Write-Host ""
    Write-Error2 "Setup failed: $($_.Exception.Message)"
    Write-Host ""
    Write-Info "If you need help, please visit:"
    Write-Info "  https://docs.github.com/copilot/concepts/agents/about-copilot-cli"
    Write-Host ""
    exit 1
}

#endregion
