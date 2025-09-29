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
    Installs WorkMode module from GitHub repository.
.DESCRIPTION
    This script downloads and sets up the WorkMode productivity system by downloading files
    from the GitHub repository, configuring directories, and providing manual profile integration instructions.
.EXAMPLE
    .\install-workmode.ps1
.EXAMPLE
    irm https://raw.githubusercontent.com/haikalllp/WorkMode-Hostess/main/scripts/install-workmode.ps1 | iex
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Force,
    [Parameter()]
    [string]$InstallPath = "$env:USERPROFILE\Documents\PowerShell\Modules\WorkMode"
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Script configuration
$ScriptName = "WorkMode Installer"
$Version = "1.0"
$GitHubRepo = "haikalllp/WorkMode-Hostess"
$GitHubRawBaseUrl = "https://raw.githubusercontent.com/$GitHubRepo/main"
$HostessGitHubRepo = "cbednarski/hostess"
$HostessGitHubApiUrl = "https://api.github.com/repos/$HostessGitHubRepo/releases/latest"

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

function Invoke-WebRequestWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        [Parameter(Mandatory=$false)]
        [int]$MaxRetries = 3,
        [Parameter(Mandatory=$false)]
        [int]$RetryDelaySeconds = 2
    )

    $retryCount = 0
    while ($retryCount -lt $MaxRetries) {
        try {
            $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing
            return $response
        } catch {
            $retryCount++
            if ($retryCount -ge $MaxRetries) {
                Write-Error "Failed to download from $Uri after $MaxRetries attempts: $($_.Exception.Message)"
                throw
            }
            Write-Warning "Download attempt $retryCount failed. Retrying in $RetryDelaySeconds seconds..."
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
}

function Get-LatestHostessRelease {
    [CmdletBinding()]
    param()

    Write-Step "Getting latest hostess release information"
    try {
        $response = Invoke-WebRequestWithRetry -Uri $HostessGitHubApiUrl
        $releaseInfo = $response.Content | ConvertFrom-Json
        Write-Success "Found hostess version: $($releaseInfo.tag_name)"
        return $releaseInfo
    } catch {
        Write-Error "Failed to get hostess release information: $($_.Exception.Message)"
        throw
    }
}

function Download-HostessBinary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$ReleaseInfo,
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )

    Write-Step "Downloading hostess binary"

    # Find the Windows amd64 asset
    $asset = $ReleaseInfo.assets | Where-Object { $_.name -match "hostess_windows_amd64\.exe" } | Select-Object -First 1
    if (-not $asset) {
        Write-Error "Could not find Windows amd64 binary in hostess release"
        throw "Hostess binary not found"
    }

    $hostessDestPath = Join-Path $DestinationPath "hostess.exe"
    try {
        Write-Step "Downloading $($asset.name)"
        $response = Invoke-WebRequestWithRetry -Uri $asset.browser_download_url
        [System.IO.File]::WriteAllBytes($hostessDestPath, $response.Content)
        Write-Success "Downloaded hostess binary to: $hostessDestPath"
        return $hostessDestPath
    } catch {
        Write-Error "Failed to download hostess binary: $($_.Exception.Message)"
        throw
    }
}

function Download-WorkModeFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )

    Write-Step "Downloading WorkMode files from GitHub repository"

    # Create destination directory
    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        Write-Success "Created directory: $DestinationPath"
    }

    # Files to download from GitHub
    $filesToDownload = @(
        @{ Source = "WorkMode.psm1"; Dest = "WorkMode.psm1" },
        @{ Source = "WorkMode.psd1"; Dest = "WorkMode.psd1" },
        @{ Source = "config/work-sites.json"; Dest = "config/work-sites.json" }
    )

    foreach ($file in $filesToDownload) {
        $sourceUrl = "$GitHubRawBaseUrl/$($file.Source)"
        $destPath = Join-Path $DestinationPath $file.Dest

        # Create directory if needed
        $destDir = Split-Path $destPath -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        try {
            Write-Step "Downloading $($file.Source)"
            $response = Invoke-WebRequestWithRetry -Uri $sourceUrl
            $response.Content | Set-Content -Path $destPath -Force
            Write-Success "Downloaded $($file.Source) to: $destPath"
        } catch {
            Write-Error "Failed to download $($file.Source): $($_.Exception.Message)"
            throw
        }
    }
}

function Show-ProfileIntegrationInstructions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$WorkModePath
    )

    Write-Host ""
    Write-Host "📋 Manual Profile Integration Required" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To complete the installation, you need to add WorkMode to your PowerShell profile:" -ForegroundColor White
    Write-Host ""
    Write-Host "1. Open your PowerShell profile:" -ForegroundColor Cyan
    Write-Host "   notepad `$PROFILE" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Add the following line to import WorkMode:" -ForegroundColor Cyan
    Write-Host "   Import-Module \"$WorkModePath\WorkMode.psm1\" -Force" -ForegroundColor White
    Write-Host ""
    Write-Host "3. For prompt integration and enhanced features, see the README.md" -ForegroundColor Cyan
    Write-Host "   for detailed profile integration instructions." -ForegroundColor White
    Write-Host ""
    Write-Host "4. Save the profile and restart PowerShell, or run:" -ForegroundColor Cyan
    Write-Host "   . `$PROFILE" -ForegroundColor White
    Write-Host ""
    Write-Host "After integration, you can use commands like:" -ForegroundColor Yellow
    Write-Host "  wmh-on, wmh-off, wmh-status, wmh-stats" -ForegroundColor White
    Write-Host ""
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

    # Check internet connectivity
    try {
        Write-Step "Testing internet connectivity"
        $testResponse = Invoke-WebRequest -Uri "https://raw.githubusercontent.com" -UseBasicParsing -TimeoutSec 10
        Write-Success "Internet connectivity confirmed"
    } catch {
        Write-Error "Unable to connect to GitHub. Please check your internet connection."
        return $false
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
    Write-Host "  wmh-on      - Start WorkMode (block distractions)" -ForegroundColor White
    Write-Host "  wmh-off     - Stop WorkMode (allow distractions)" -ForegroundColor White
    Write-Host "  wmh-status  - Show current status" -ForegroundColor White
    Write-Host "  wmh-stats   - View productivity statistics" -ForegroundColor White
    Write-Host ""
    Write-Host "Website Management:" -ForegroundColor Yellow
    Write-Host "  wmh-add example.com     - Add site to block list" -ForegroundColor White
    Write-Host "  wmh-remove example.com  - Remove site from block list" -ForegroundColor White
    Write-Host "  wmh-list              - List all blocked sites" -ForegroundColor White
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Yellow
    Write-Host "  Module Directory: $InstallPath" -ForegroundColor White
    Write-Host "  Data Directory: $env:USERPROFILE\Documents\PowerShell\WorkMode" -ForegroundColor White
    Write-Host "  Time Tracking File: time-tracking.json" -ForegroundColor White
    Write-Host "  Sites Configuration: work-sites.json" -ForegroundColor White
    Write-Host ""
    Write-Host "📝 Follow the profile integration instructions above to complete setup!" -ForegroundColor Cyan
    Write-Host ""
}

# Main installation process
function Install-WorkMode {
    [CmdletBinding()]
    param()

    Write-Host "$ScriptName v$Version" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Installing WorkMode from: $GitHubRepo" -ForegroundColor White
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

    # Download WorkMode files
    Download-WorkModeFiles -DestinationPath $InstallPath

    # Download hostess binary
    try {
        $releaseInfo = Get-LatestHostessRelease
        Download-HostessBinary -ReleaseInfo $releaseInfo -DestinationPath $InstallPath
    } catch {
        Write-Warning "Failed to download hostess binary: $($_.Exception.Message)"
        Write-Warning "You can manually download it later using: Update-WorkMode"
    }

    # Show installation summary
    Show-InstallationSummary -InstallPath $InstallPath

    # Show profile integration instructions
    Show-ProfileIntegrationInstructions -WorkModePath $InstallPath

    Write-Success "WorkMode installation completed successfully!"
}

# Run installation if called directly
if ($MyInvocation.InvocationName -ne '.') {
    Install-WorkMode
}