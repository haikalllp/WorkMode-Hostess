#!/usr/bin/env pwsh

###############################################################################
#                                                                             #
#                    WorkMode Automated Installation Script                   #
#                                                                             #
#        Downloads hostess from GitHub and installs WorkMode module           #
#                                                                             #
#                               Version 2.0                                   #
#                                                                             #
###############################################################################

<#
.SYNOPSIS
    Automated WorkMode installation script with GitHub integration.
.DESCRIPTION
    Downloads the latest hostess binary from GitHub releases and installs WorkMode
    as a proper PowerShell module with all dependencies. This script is designed for
    users who have cloned the WorkMode repository locally.
.PARAMETER InstallPath
    Custom installation path. Default: "$env:USERPROFILE\Documents\PowerShell\Modules\WorkMode"
.PARAMETER DataPath
    Custom data path. Default: "$env:USERPROFILE\Documents\PowerShell\WorkMode"
.PARAMETER Force
    Force reinstallation even if WorkMode is already installed.
.PARAMETER Offline
    Skip downloading from GitHub and use local hostess binary only (if available).
.PARAMETER Repair
    Repair existing installation.
.PARAMETER Uninstall
    Uninstall WorkMode.
.PARAMETER Proxy
    Proxy server for downloads.
.PARAMETER ShowProfileInstructions
    Show manual profile integration instructions.
.EXAMPLE
    .\install-local.ps1
    Downloads hostess from GitHub and installs WorkMode
.EXAMPLE
    .\install-local.ps1 -Force
    Force reinstallation with fresh downloads
.EXAMPLE
    .\install-local.ps1 -Offline
    Use local files only (requires hostess binary to be present)
.EXAMPLE
    .\install-local.ps1 -Uninstall
    Uninstall WorkMode
.EXAMPLE
    .\install-local.ps1 -Proxy "http://proxy:8080"
    Use proxy server for downloads
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$InstallPath = "$env:USERPROFILE\Documents\PowerShell\Modules\WorkMode",

    [Parameter()]
    [string]$DataPath = "$env:USERPROFILE\Documents\PowerShell\WorkMode",

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$Offline,

    [Parameter()]
    [switch]$Repair,

    [Parameter()]
    [switch]$Uninstall,

    [Parameter()]
    [string]$Proxy,

    [Parameter()]
    [switch]$ShowProfileInstructions
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Script configuration
$ScriptName = "WorkMode Installer"
$Version = "2.0"
$GitHubRepo = "cbednarski/hostess"
$GitHubApiUrl = "https://api.github.com/repos/$GitHubRepo/releases/latest"
$TempDir = Join-Path $env:TEMP "WorkModeInstall"
$LogFile = Join-Path $TempDir "install-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Create temporary directory
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
}

# Logging function
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter()]
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to log file
    Add-Content -Path $LogFile -Value $logMessage

    # Write to console with colors
    switch ($Level) {
        "Info"    { Write-Host "$Message" -ForegroundColor White }
        "Success" { Write-Host "✅ $Message" -ForegroundColor Green }
        "Warning" { Write-Host "⚠️  $Message" -ForegroundColor Yellow }
        "Error"   { Write-Host "❌ $Message" -ForegroundColor Red }
    }
}

# Utility functions
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-WebRequestWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,

        [Parameter()]
        [string]$OutFile,

        [Parameter()]
        [int]$MaxRetries = 3,

        [Parameter()]
        [int]$RetryDelay = 2
    )

    $webParams = @{
        Uri = $Uri
        UseBasicParsing = $true
    }

    if ($Proxy) {
        $webParams.Proxy = New-Object System.Net.WebProxy($Proxy)
    }

    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            if ($OutFile) {
                $webParams.OutFile = $OutFile
                Invoke-WebRequest @webParams
                Write-Log "Downloaded: $(Split-Path $Uri -Leaf)" -Level Success
                return $true
            } else {
                $response = Invoke-WebRequest @webParams
                return $response
            }
        } catch {
            Write-Log "Download attempt $i failed: $($_.Exception.Message)" -Level Warning
            if ($i -lt $MaxRetries) {
                Write-Log "Retrying in $RetryDelay seconds..." -Level Info
                Start-Sleep -Seconds $RetryDelay
            }
        }
    }

    throw "Failed to download after $MaxRetries attempts: $Uri"
}

function Get-LatestHostessRelease {
    [CmdletBinding()]
    param()

    Write-Log "Fetching latest hostess release from GitHub..." -Level Info

    try {
        $response = Invoke-WebRequestWithRetry -Uri $GitHubApiUrl
        $releaseInfo = $response.Content | ConvertFrom-Json

        Write-Log "Latest version: $($releaseInfo.tag_name)" -Level Info
        Write-Log "Release date: $($releaseInfo.published_at)" -Level Info

        return $releaseInfo
    } catch {
        Write-Log "Failed to fetch release info: $($_.Exception.Message)" -Level Error
        throw "Failed to fetch latest hostess release from GitHub"
    }
}

function Find-HostessAsset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$ReleaseInfo
    )

    # Look for Windows AMD64 binary
    $patterns = @(
        "*windows*amd64*.exe",
        "*windows*.exe",
        "*hostess*.exe"
    )

    foreach ($pattern in $patterns) {
        $asset = $ReleaseInfo.assets | Where-Object { $_.name -like $pattern } | Select-Object -First 1
        if ($asset) {
            Write-Log "Found hostess binary: $($asset.name)" -Level Success
            return $asset
        }
    }

    throw "No suitable hostess binary found in release assets"
}

function Test-HostessBinary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$BinaryPath
    )

    try {
        & $BinaryPath --help | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Hostess binary verified successfully" -Level Success
            return $true
        }
    } catch {
        Write-Log "Hostess binary test failed: $($_.Exception.Message)" -Level Warning
    }

    return $false
}

function Backup-ExistingInstallation {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Path
    )

    if (Test-Path $Path) {
        $backupPath = "$Path.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        try {
            Copy-Item -Path $Path -Destination $backupPath -Recurse -Force
            Write-Log "Backed up existing installation to: $backupPath" -Level Success
            return $backupPath
        } catch {
            Write-Log "Failed to backup existing installation: $($_.Exception.Message)" -Level Warning
        }
    }
    return $null
}

function Remove-ExistingInstallation {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Path
    )

    if (Test-Path $Path) {
        try {
            Remove-Item -Path $Path -Recurse -Force
            Write-Log "Removed existing installation: $Path" -Level Success
        } catch {
            Write-Log "Failed to remove existing installation: $($_.Exception.Message)" -Level Warning
            throw "Failed to remove existing installation"
        }
    }
}

function Install-WorkModeModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstallPath,

        [Parameter(Mandatory=$true)]
        [string]$DataPath,

        [Parameter(Mandatory=$true)]
        [string]$BinaryPath
    )

    Write-Log "Installing WorkMode module to: $InstallPath" -Level Info

    # Create module directory
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
        Write-Log "Created module directory: $InstallPath" -Level Success
    }

    # Create data directory
    if (-not (Test-Path $DataPath)) {
        New-Item -ItemType Directory -Path $DataPath -Force | Out-Null
        Write-Log "Created data directory: $DataPath" -Level Success
    }

    # Copy module files
    $moduleFiles = @(
        "WorkMode.psm1",
        "config\work-sites.json"
    )

    foreach ($file in $moduleFiles) {
        $sourceFile = Join-Path $PSScriptRoot $file
        $destFile = Join-Path $InstallPath $file

        if (Test-Path $sourceFile) {
            $destDir = Split-Path $destFile -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }

            Copy-Item -Path $sourceFile -Destination $destFile -Force
            Write-Log "Copied: $file" -Level Success
        } else {
            Write-Log "Source file not found: $sourceFile" -Level Warning
        }
    }

    # Copy hostess binary
    $hostessDest = Join-Path $InstallPath "hostess.exe"
    Copy-Item -Path $BinaryPath -Destination $hostessDest -Force
    Write-Log "Copied hostess binary" -Level Success

    # Test module installation
    try {
        Import-Module $InstallPath\WorkMode.psm1 -Force -ErrorAction Stop
        Write-Log "Module imported successfully" -Level Success

        # Test basic functionality
        if (Get-Command Enable-WorkMode -ErrorAction SilentlyContinue) {
            Write-Log "WorkMode functions available" -Level Success
        } else {
            throw "WorkMode functions not available after import"
        }
    } catch {
        Write-Log "Module test failed: $($_.Exception.Message)" -Level Error
        throw "Failed to install WorkMode module"
    }
}

function Show-ManualIntegrationInstructions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModulePath
    )

    Write-Host ""
    Write-Host "📋 Manual Profile Integration Required" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To complete the installation, add the following code to your PowerShell profile:" -ForegroundColor White
    Write-Host ""
    Write-Host "Profile location: $PROFILE" -ForegroundColor Cyan
    Write-Host ""

    $integrationCode = @"
#region WORKMODE INTEGRATION
# Import WorkMode module
`$workModeModulePath = "$ModulePath"
if (Test-Path `$workModeModulePath) {
    try {
        Import-Module "`$workModeModulePath\WorkMode.psm1" -Force -ErrorAction Stop
        Write-Host "WorkMode module loaded successfully!" -ForegroundColor Green
        Write-Host "Use 'wmh-on' to start focus time, 'wmh-off' for breaks" -ForegroundColor Cyan

        # Show WorkMode status on startup
        if (Get-Command Get-WorkModeStatus -ErrorAction SilentlyContinue) {
            Write-Host ""
            Get-WorkModeStatus
            Write-Host ""
        }
    } catch {
        Write-Warning "Failed to load WorkMode module: `$(`$_`Exception.Message)"
    }
}

# WorkMode prompt integration
`$script:WorkModeStatus = `$null

function Update-WorkModePromptStatus {
    if (Get-Command Get-WorkModeStatus -ErrorAction SilentlyContinue) {
        try {
            `$script:WorkModeStatus = Get-WorkModeStatus -ErrorAction SilentlyContinue
        } catch {
            `$script:WorkModeStatus = `$null
        }
    }
}

# Update prompt function (replace existing prompt function)
function prompt {
    # Update WorkMode status
    Update-WorkModePromptStatus

    # Build base prompt
    `$location = Get-Location
    `$basePrompt = "[`$location]"

    # Add WorkMode status if available
    if (`$script:WorkModeStatus -and `$script:WorkModeStatus.Mode) {
        `$modeIcon = if (`$script:WorkModeStatus.Mode -eq "Work") { "🔴" } else { "🟢" }
        `$basePrompt += " `$modeIcon`$(`$script:WorkModeStatus.Mode)"
    }

    # Add admin prompt
    `$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (`$isAdmin) {
        `$basePrompt += " # "
    } else {
        `$basePrompt += " `$ "
    }

    return `$basePrompt
}
#endregion
"@

    Write-Host $integrationCode -ForegroundColor Gray
    Write-Host ""
    Write-Host "Alternatively, you can manually import the module in each session:" -ForegroundColor White
    Write-Host "Import-Module '$ModulePath\WorkMode.psm1'" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Installation {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$InstallPath
    )

    Write-Log "Testing installation..." -Level Info

    $tests = @(
        @{
            Name = "Module Directory"
            Test = { Test-Path $InstallPath }
            Message = "Module directory exists"
        },
        @{
            Name = "Module File"
            Test = { Test-Path (Join-Path $InstallPath "WorkMode.psm1") }
            Message = "Module file exists"
        },
        @{
            Name = "Hostess Binary"
            Test = { Test-Path (Join-Path $InstallPath "hostess.exe") }
            Message = "Hostess binary exists"
        },
        @{
            Name = "Config File"
            Test = { Test-Path (Join-Path $InstallPath "config\work-sites.json") }
            Message = "Configuration file exists"
        },
        @{
            Name = "Module Import"
            Test = {
                try {
                    Import-Module (Join-Path $InstallPath "WorkMode.psm1") -Force -ErrorAction Stop
                    $true
                } catch {
                    $false
                }
            }
            Message = "Module can be imported"
        },
        @{
            Name = "WorkMode Commands"
            Test = { Get-Command Enable-WorkMode -ErrorAction SilentlyContinue }
            Message = "WorkMode commands available"
        }
    )

    $passed = 0
    $total = $tests.Count

    foreach ($test in $tests) {
        try {
            $result = & $test.Test
            if ($result) {
                Write-Log "✓ $($test.Message)" -Level Success
                $passed++
            } else {
                Write-Log "✗ $($test.Message)" -Level Error
            }
        } catch {
            Write-Log "✗ $($test.Message): $($_.Exception.Message)" -Level Error
        }
    }

    Write-Log "Installation tests: $passed/$total passed" -Level Info

    if ($passed -eq $total) {
        Write-Log "All tests passed!" -Level Success
        return $true
    } else {
        Write-Log "Some tests failed" -Level Warning
        return $false
    }
}

function Show-InstallationSummary {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$InstallPath,

        [Parameter()]
        [string]$DataPath
    )

    Write-Host ""
    Write-Host "🎉 WorkMode Installation Complete!" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Installation Path: $InstallPath" -ForegroundColor White
    Write-Host "Data Path: $DataPath" -ForegroundColor White
    Write-Host "Log File: $LogFile" -ForegroundColor White
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
}

function Uninstall-WorkMode {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$InstallPath,

        [Parameter()]
        [string]$DataPath
    )

    Write-Log "Starting uninstallation..." -Level Info

    # Remove module installation
    if (Test-Path $InstallPath) {
        try {
            Remove-Item -Path $InstallPath -Recurse -Force
            Write-Log "Removed module directory: $InstallPath" -Level Success
        } catch {
            Write-Log "Failed to remove module directory: $($_.Exception.Message)" -Level Warning
        }
    }

    # Ask about data removal
    if (Test-Path $DataPath) {
        $response = Read-Host "Remove user data? (y/N) [default: N]"
        if ($response -match '^[yY]$') {
            try {
                Remove-Item -Path $DataPath -Recurse -Force
                Write-Log "Removed data directory: $DataPath" -Level Success
            } catch {
                Write-Log "Failed to remove data directory: $($_.Exception.Message)" -Level Warning
            }
        } else {
            Write-Log "User data preserved: $DataPath" -Level Info
        }
    }

    Write-Log "Uninstallation completed" -Level Success
}

# Main installation logic
function Install-WorkMode {
    [CmdletBinding()]
    param()

    Write-Host "$ScriptName v$Version" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Cyan
    Write-Host ""

    # Check administrator privileges
    if (-not (Test-Administrator)) {
        Write-Log "Running without administrator privileges. Some features may require admin rights for hosts file modification." -Level Warning
    }

    # Handle uninstall
    if ($Uninstall) {
        Uninstall-WorkMode -InstallPath $InstallPath -DataPath $DataPath
        Write-Host "WorkMode has been uninstalled." -ForegroundColor Green
        return
    }

    # Download hostess from GitHub (default behavior)
    try {
        Write-Log "Checking for latest hostess release..." -Level Info
        $releaseInfo = Get-LatestHostessRelease
        $asset = Find-HostessAsset -ReleaseInfo $releaseInfo

        $binaryPath = Join-Path $TempDir $asset.name

        if (-not (Test-Path $binaryPath) -or $Force) {
            Write-Log "Downloading hostess binary..." -Level Info
            Invoke-WebRequestWithRetry -Uri $asset.browser_download_url -OutFile $binaryPath
        } else {
            Write-Log "Using existing downloaded binary" -Level Info
        }

        # Test downloaded binary
        if (-not (Test-HostessBinary -BinaryPath $binaryPath)) {
            throw "Downloaded hostess binary is not working"
        }
    } catch {
        Write-Log "Failed to download hostess from GitHub: $($_.Exception.Message)" -Level Error

        # Fallback to offline mode if download fails and local binary exists
        if ($Offline -and (Test-Path (Join-Path $PSScriptRoot "hostess_windows_amd64.exe"))) {
            Write-Log "Falling back to local hostess binary" -Level Info
            $binaryPath = Join-Path $PSScriptRoot "hostess_windows_amd64.exe"
        } else {
            Write-Log "You can download hostess manually from: https://github.com/cbednarski/hostess/releases/latest" -Level Info
            throw "Hostess download failed. Use -Offline if you have a local binary."
        }
    }

    # Check for existing installation
    if ((Test-Path $InstallPath) -and -not $Force -and -not $Repair) {
        Write-Log "WorkMode is already installed at: $InstallPath" -Level Warning
        Write-Log "Use -Force to reinstall or -Repair to fix issues" -Level Info
        return
    }

    # Backup existing installation
    $backupPath = $null
    if ((Test-Path $InstallPath) -and ($Force -or $Repair)) {
        $backupPath = Backup-ExistingInstallation -Path $InstallPath
    }

    try {
        # Remove existing installation for clean install
        if ($Force -or $Repair) {
            Remove-ExistingInstallation -Path $InstallPath
        }

        # Install WorkMode module
        Install-WorkModeModule -InstallPath $InstallPath -DataPath $DataPath -BinaryPath $binaryPath

        # Test installation
        if (-not (Test-Installation -InstallPath $InstallPath)) {
            throw "Installation tests failed"
        }

        # Show manual integration instructions
        if ($ShowProfileInstructions) {
            Show-ManualIntegrationInstructions -ModulePath $InstallPath
        }

        # Show summary
        Show-InstallationSummary -InstallPath $InstallPath -DataPath $DataPath

        Write-Log "Installation completed successfully!" -Level Success

    } catch {
        Write-Log "Installation failed: $($_.Exception.Message)" -Level Error

        # Restore from backup if available
        if ($backupPath -and (Test-Path $backupPath)) {
            Write-Log "Restoring from backup..." -Level Info
            try {
                Remove-ExistingInstallation -Path $InstallPath
                Copy-Item -Path $backupPath -Destination $InstallPath -Recurse -Force
                Write-Log "Installation restored from backup" -Level Success
            } catch {
                Write-Log "Failed to restore from backup: $($_.Exception.Message)" -Level Warning
            }
        }

        throw "Installation failed. Check log file: $LogFile"
    }
}

# Run installation if called directly
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Install-WorkMode
    } catch {
        Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Check log file for details: $LogFile" -ForegroundColor Yellow
        exit 1
    }
}