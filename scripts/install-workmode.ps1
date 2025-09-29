#!/usr/bin/env pwsh

###############################################################################
#                                                                             #
#                          WorkMode Installation Script                       #
#                                                                             #
#        Installs and configures WorkMode for productivity tracking             #
#        and website blocking using hostess                                   #
#                                                                             #
#                               Version 1.0                                   #
#                                                                             #
###############################################################################

<#
.SYNOPSIS
    Installs WorkMode module and integrates it with PowerShell profile.
.DESCRIPTION
    This script sets up the WorkMode productivity system by copying necessary files,
    configuring directories, and integrating with the existing PowerShell profile.
.EXAMPLE
    .\install-workmode.ps1
.EXAMPLE
    Install-WorkMode
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Force,
    [Parameter()]
    [string]$InstallPath = "$env:USERPROFILE\Documents\PowerShell\WorkMode"
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Script configuration
$ScriptName = "WorkMode Installer"
$Version = "1.0"
$RequiredFiles = @(
    "WorkMode.psm1",
    "hostess_windows_amd64.exe",
    "config\work-sites.json"
)

# Utility functions
function Write-Step {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    Write-Host "➡️  $Message" -ForegroundColor Cyan
}

function Write-Success {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    Write-Host "❌ $Message" -ForegroundColor Red
}

function Test-Administrator {
    [CmdletBinding()]
    param()

    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Backup-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if (Test-Path $Path) {
        $backupPath = "$Path.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $Path -Destination $backupPath -Force
        Write-Success "Backed up existing file to: $backupPath"
        return $backupPath
    }
    return $null
}

function Copy-WorkModeFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )

    Write-Step "Copying WorkMode files to: $DestinationPath"

    # Create destination directory
    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        Write-Success "Created directory: $DestinationPath"
    }

    # Copy module file
    $moduleSource = Join-Path $SourcePath "WorkMode.psm1"
    $moduleDest = Join-Path $DestinationPath "WorkMode.psm1"
    Copy-Item -Path $moduleSource -Destination $moduleDest -Force
    Write-Success "Copied WorkMode.psm1"

    # Copy hostess binary
    $hostessSource = Join-Path $SourcePath "hostess_windows_amd64.exe"
    $hostessDest = Join-Path $DestinationPath "hostess_windows_amd64.exe"
    Copy-Item -Path $hostessSource -Destination $hostessDest -Force
    Write-Success "Copied hostess binary"

    # Copy config files
    $configDest = Join-Path $DestinationPath "config"
    if (-not (Test-Path $configDest)) {
        New-Item -ItemType Directory -Path $configDest -Force | Out-Null
    }

    $configSource = Join-Path $SourcePath "config\work-sites.json"
    $configFileDest = Join-Path $configDest "work-sites.json"
    Copy-Item -Path $configSource -Destination $configFileDest -Force
    Write-Success "Copied configuration files"
}

function Update-PowerShellProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$WorkModePath
    )

    Write-Step "Updating PowerShell profile"

    $profilePath = $PROFILE.CurrentUserCurrentHost
    if (-not (Test-Path $profilePath)) {
        Write-Warning "PowerShell profile not found at: $profilePath"
        return $false
    }

    # Backup existing profile
    $backupPath = Backup-File -Path $profilePath

    # Read current profile content
    $profileContent = Get-Content -Path $profilePath -Raw

    # Check if WorkMode integration already exists
    if ($profileContent -match "#region WORKMODE INTEGRATION") {
        if ($Force) {
            Write-Warning "WorkMode integration already exists. Force mode enabled - replacing."
            # Remove existing WorkMode integration
            $profileContent = $profileContent -replace "(?s)#region WORKMODE INTEGRATION.*?#endregion", ""
            $profileContent = $profileContent.Trim()
        } else {
            Write-Warning "WorkMode integration already exists in profile. Use -Force to reinstall."
            return $false
        }
    }

    # Prepare WorkMode integration code
    $workModeIntegration = @"

#region WORKMODE INTEGRATION
<#
.SYNOPSIS
    WorkMode Integration for Productivity Tracking
.DESCRIPTION
    Integrates WorkMode module for time tracking and website blocking
    to help improve productivity and focus during work sessions.
#>

# Import WorkMode module if available
`$workModeModulePath = Join-Path "$WorkModePath" "WorkMode.psm1"
if (Test-Path `$workModeModulePath) {
    try {
        Import-Module `$workModeModulePath -Force -ErrorAction Stop
        Write-Host "WorkMode module loaded successfully!" -ForegroundColor Green
        Write-Host "Use 'work-on' to start focus time, 'work-off' for breaks" -ForegroundColor Cyan
    } catch {
        Write-Warning "Failed to load WorkMode module: `$(`$_`Exception.Message)"
    }
}

# WorkMode prompt integration
`$script:WorkModeStatus = `$null

function Update-WorkModePromptStatus {
    if (Get-Command Get-WorkModeStatus -ErrorAction SilentlyContinue) {
        try {
            # Try to get current session info from WorkMode module
            `$script:WorkModeStatus = Get-WorkModeStatus -ErrorAction SilentlyContinue
        } catch {
            `$script:WorkModeStatus = `$null
        }
    }
}

# Show WorkMode status on startup
if (Get-Command Get-WorkModeStatus -ErrorAction SilentlyContinue) {
    Write-Host ""
    Get-WorkModeStatus
    Write-Host ""
}
#endregion
"@

    # Add WorkMode integration to profile
    $newProfileContent = $profileContent + $workModeIntegration

    # Save updated profile
    $newProfileContent | Set-Content -Path $profilePath -Force
    Write-Success "Updated PowerShell profile with WorkMode integration"

    return $true
}

function Update-PromptFunction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProfilePath
    )

    Write-Step "Updating prompt function"

    # Read profile content
    $profileContent = Get-Content -Path $ProfilePath -Raw

    # Find and replace the prompt function
    $promptPattern = '(?s)function prompt \{.*?^\}'

    $newPromptFunction = @'
function prompt {
    # Update WorkMode status
    Update-WorkModePromptStatus

    # Build base prompt
    $location = Get-Location
    $basePrompt = "[$location]"

    # Add WorkMode status if available
    if ($script:WorkModeStatus -and $script:WorkModeStatus.Mode) {
        $modeIcon = if ($script:WorkModeStatus.Mode -eq "Work") { "🔴" } else { "🟢" }
        $basePrompt += " $modeIcon$($script:WorkModeStatus.Mode)"
    }

    # Add admin prompt
    if ($isAdmin) {
        $basePrompt += " # "
    } else {
        $basePrompt += " $ "
    }

    return $basePrompt
}
'@

    if ($profileContent -match $promptPattern) {
        $profileContent = $profileContent -replace $promptPattern, $newPromptFunction
        $profileContent | Set-Content -Path $ProfilePath -Force
        Write-Success "Updated prompt function to show WorkMode status"
    } else {
        Write-Warning "Could not find prompt function in profile"
    }
}

function Test-Prerequisites {
    [CmdletBinding()]
    param()

    Write-Step "Checking prerequisites"

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error "PowerShell version 5 or higher is required. Current version: $($PSVersionTable.PSVersion)"
        return $false
    }
    Write-Success "PowerShell version: $($PSVersionTable.PSVersion)"

    # Check if running as administrator (optional but recommended)
    if (Test-Administrator) {
        Write-Success "Running with administrator privileges"
    } else {
        Write-Warning "Not running as administrator. Some features may require admin rights for hosts file modification."
    }

    # Check required files
    $scriptPath = $PSScriptRoot
    foreach ($file in $RequiredFiles) {
        $filePath = Join-Path $scriptPath $file
        if (-not (Test-Path $filePath)) {
            Write-Error "Required file not found: $filePath"
            return $false
        }
        Write-Success "Found required file: $file"
    }

    return $true
}

function Show-InstallationSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstallPath
    )

    Write-Host ""
    Write-Host "🎉 WorkMode Installation Complete!" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Installation Path: $InstallPath" -ForegroundColor White
    Write-Host ""
    Write-Host "Quick Start Commands:" -ForegroundColor Yellow
    Write-Host "  work-on      - Start WorkMode (block distractions)" -ForegroundColor White
    Write-Host "  work-off     - Stop WorkMode (allow distractions)" -ForegroundColor White
    Write-Host "  work-status  - Show current status" -ForegroundColor White
    Write-Host "  work-stats   - View productivity statistics" -ForegroundColor White
    Write-Host ""
    Write-Host "Website Management:" -ForegroundColor Yellow
    Write-Host "  add-block-site example.com     - Add site to block list" -ForegroundColor White
    Write-Host "  remove-block-site example.com  - Remove site from block list" -ForegroundColor White
    Write-Host "  show-block-sites              - List all blocked sites" -ForegroundColor White
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Yellow
    Write-Host "  Data Directory: $env:USERPROFILE\Documents\PowerShell\WorkMode" -ForegroundColor White
    Write-Host "  Time Tracking File: time-tracking.json" -ForegroundColor White
    Write-Host "  Sites Configuration: work-sites.json" -ForegroundColor White
    Write-Host ""
    Write-Host "📝 Open a new PowerShell session to start using WorkMode!" -ForegroundColor Cyan
    Write-Host ""
}

# Main installation process
function Install-WorkMode {
    [CmdletBinding()]
    param()

    $scriptPath = $PSScriptRoot

    Write-Host "$ScriptName v$Version" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Cyan
    Write-Host ""

    # Test prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Error "Prerequisites check failed. Installation aborted."
        exit 1
    }

    # Create installation directory
    Write-Step "Creating installation directory"
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
        Write-Success "Created installation directory: $InstallPath"
    }

    # Copy WorkMode files
    Copy-WorkModeFiles -SourcePath $scriptPath -DestinationPath $InstallPath

    # Update PowerShell profile
    if (-not (Update-PowerShellProfile -WorkModePath $InstallPath)) {
        Write-Error "Failed to update PowerShell profile"
        exit 1
    }

    # Update prompt function
    $profilePath = $PROFILE.CurrentUserCurrentHost
    Update-PromptFunction -ProfilePath $profilePath

    # Show installation summary
    Show-InstallationSummary -InstallPath $InstallPath

    Write-Success "WorkMode installation completed successfully!"
}

# Export functions
Export-ModuleMember -Function 'Install-WorkMode'

# Run installation if called directly
if ($MyInvocation.InvocationName -ne '.') {
    Install-WorkMode
}