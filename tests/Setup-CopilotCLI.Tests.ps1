BeforeAll {
    # Load the script functions without executing main
    $scriptPath = Join-Path $PSScriptRoot '..' 'Setup-CopilotCLI.ps1'
    $scriptContent = Get-Content -Path $scriptPath -Raw

    # Extract everything before the MAIN region
    $functionsOnly = ($scriptContent -split '#region.*═+\s*\n# MAIN')[0]

    # Remove the script-level param block (CmdletBinding + param)
    $functionsOnly = $functionsOnly -replace '(?s)\[CmdletBinding\(\)\]\s*param\s*\([^)]*\)', ''

    # Also remove Set-StrictMode and ErrorActionPreference (they interfere with testing)
    $functionsOnly = $functionsOnly -replace "Set-StrictMode.*", ''
    $functionsOnly = $functionsOnly -replace "\`\$ErrorActionPreference.*", ''

    # Create a temp script with just the functions, setting params as variables
    $tempScript = Join-Path $TestDrive 'functions.ps1'
    $preamble = @'
$NonInteractive = $true
$SkipInstructions = $true
'@
    Set-Content -Path $tempScript -Value ($preamble + "`n" + $functionsOnly)
    . $tempScript
}

Describe 'Script Syntax' {
    It 'Should parse without errors' {
        $scriptPath = Join-Path $PSScriptRoot '..' 'Setup-CopilotCLI.ps1'
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $scriptPath, [ref]$null, [ref]$errors
        )
        $errors.Count | Should -Be 0
    }
}

Describe 'Helper Functions' {
    Context 'Write-Banner' {
        It 'Should execute without error' {
            { Write-Banner } | Should -Not -Throw
        }
    }

    Context 'Write-Step' {
        It 'Should execute without error' {
            { Write-Step "Test message" } | Should -Not -Throw
        }
    }

    Context 'Write-SubStep' {
        It 'Should execute without error' {
            { Write-SubStep "Test sub-step" } | Should -Not -Throw
        }
    }

    Context 'Write-Success' {
        It 'Should execute without error' {
            { Write-Success "Test success" } | Should -Not -Throw
        }
    }

    Context 'Write-Info' {
        It 'Should execute without error' {
            { Write-Info "Test info" } | Should -Not -Throw
        }
    }

    Context 'Write-SectionHeader' {
        It 'Should execute without error' {
            { Write-SectionHeader "Test Section" 1 } | Should -Not -Throw
        }
    }

    Context 'Test-CommandExists' {
        It 'Should return true for pwsh' {
            Test-CommandExists 'pwsh' | Should -Be $true
        }

        It 'Should return false for a nonexistent command' {
            Test-CommandExists 'nonexistent_command_xyz_12345' | Should -Be $false
        }
    }

    Context 'Get-UserChoice' {
        It 'Should return default when NonInteractive' {
            $result = Get-UserChoice -Prompt "Test" -Options @("A", "B", "C") -Default 1
            $result | Should -Be 1
        }
    }

    Context 'Get-UserConfirmation' {
        It 'Should return default (true) when NonInteractive' {
            $result = Get-UserConfirmation -Prompt "Test?" -Default $true
            $result | Should -Be $true
        }

        It 'Should return default (false) when NonInteractive' {
            $result = Get-UserConfirmation -Prompt "Test?" -Default $false
            $result | Should -Be $false
        }
    }
}

Describe 'Refresh-PathEnv' {
    It 'Should execute without error' {
        { Refresh-PathEnv } | Should -Not -Throw
    }
}

Describe 'Script Structure' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..' 'Setup-CopilotCLI.ps1'
        $content = Get-Content -Path $scriptPath -Raw
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
        $script:functions = $ast.FindAll(
            { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] },
            $true
        )
    }

    It 'Should define Write-Banner' {
        $script:functions.Name | Should -Contain 'Write-Banner'
    }

    It 'Should define Test-Prerequisites' {
        $script:functions.Name | Should -Contain 'Test-Prerequisites'
    }

    It 'Should define Select-InstallMethod' {
        $script:functions.Name | Should -Contain 'Select-InstallMethod'
    }

    It 'Should define Install-CopilotCLI' {
        $script:functions.Name | Should -Contain 'Install-CopilotCLI'
    }

    It 'Should define Start-Authentication' {
        $script:functions.Name | Should -Contain 'Start-Authentication'
    }

    It 'Should define Install-VSCodeSetup' {
        $script:functions.Name | Should -Contain 'Install-VSCodeSetup'
    }

    It 'Should define Set-CustomInstructions' {
        $script:functions.Name | Should -Contain 'Set-CustomInstructions'
    }

    It 'Should define Show-Summary' {
        $script:functions.Name | Should -Contain 'Show-Summary'
    }

    It 'Should have a try/catch main block' {
        $content = Get-Content -Path (Join-Path $PSScriptRoot '..' 'Setup-CopilotCLI.ps1') -Raw
        $content | Should -Match 'try\s*\{'
        $content | Should -Match 'catch\s*\{'
    }

    It 'Should not assign to readonly $IsWindows variable' {
        $content = Get-Content -Path (Join-Path $PSScriptRoot '..' 'Setup-CopilotCLI.ps1') -Raw
        # Match assignment like $isWindows = or $IsWindows = (but not $runningOnWindows)
        $content | Should -Not -Match '\$[Ii]s[Ww]indows\s*='
    }
}

Describe 'Custom Instructions Template' {
    It 'Set-CustomInstructions should not throw with SkipInstructions' {
        { Set-CustomInstructions } | Should -Not -Throw
    }
}
