###############################################################################
#                                                                             #
#                       PowerShell Profile Configuration                      #
#                                                                             #
#                               Version 2.0                                   #
#                                                                             #
###############################################################################

#region ENVIRONMENT SETUP & INITIALIZATION
# Debug mode flag - when enabled, skips automatic updates and shows debug info
$debug = $false

# Define the path to the file that stores the last execution time
$timeFilePath = "$env:USERPROFILE\Documents\PowerShell\LastExecutionTime.txt"

# Add w64devkit to PATH for C compiler support
$w64DevkitPath = "E:\APPS\w64devkit\bin"
if ($env:Path -notlike "*$w64DevkitPath*") {
    $env:Path = "$env:Path;$w64DevkitPath"
    Write-Verbose "Added w64devkit to PATH for C compiler support"
}

# Display debug mode warning if enabled
if ($debug) {
    Write-Host "#######################################" -ForegroundColor Red
    Write-Host "#           Debug mode enabled        #" -ForegroundColor Red
    Write-Host "#          ONLY FOR DEVELOPMENT       #" -ForegroundColor Red
    Write-Host "#                                     #" -ForegroundColor Red
    Write-Host "#       IF YOU ARE NOT DEVELOPING     #" -ForegroundColor Red
    Write-Host "#       JUST RUN \`Update-Profile\`   #" -ForegroundColor Red
    Write-Host "#        to discard all changes       #" -ForegroundColor Red
    Write-Host "#   and update to the latest profile  #" -ForegroundColor Red
    Write-Host "#               version               #" -ForegroundColor Red
    Write-Host "#######################################" -ForegroundColor Red
}

#################################################################################################################################
############                                                                                                         ############
############                                 !!!   Shrewdy's Powershell:   !!!                                       ############
############                                                                                                         ############
############                                             Based On:                                                   ############
############                       https://github.com/ChrisTitusTech/powershell-profile.git.                         ############
############                                                                                                         ############
#################################################################################################################################

# Opt-out of telemetry (only if running as admin)
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

# GitHub connectivity check with 1 second timeout (deferred)
$script:gitHubConnectionStatus = $null # Initialize session cache for connectivity status

# Function to check GitHub connectivity, caches result for the session
function Get-GitHubConnectivityStatus {
    if ($null -eq $script:gitHubConnectionStatus) {
        Write-Verbose "Performing GitHub connectivity check..."
        $script:gitHubConnectionStatus = Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1
        if ($script:gitHubConnectionStatus) {
            Write-Verbose "GitHub is reachable."
        } else {
            Write-Verbose "GitHub is not reachable (timeout or other error)."
        }
    }
    return $script:gitHubConnectionStatus
}

# Example of how to use it if needed (replace $global:canConnectToGitHub with Get-GitHubConnectivityStatus):
# if (Get-GitHubConnectivityStatus) { # Do something }

#endregion

#region PREFERENCES & SETTINGS MANAGEMENT
<#
.SYNOPSIS
    Saves user preferences to a JSON file
.DESCRIPTION
    Saves the provided hashtable of preferences to the user's PowerShell preferences file.
    Handles null input gracefully.
.PARAMETER Preferences
    A hashtable containing user preferences to save
.EXAMPLE
    Save-UserPreferences @{ Theme = "Dark"; ShowGreeting = $true }
#>
function Save-UserPreferences {
    param (
        [Parameter(Mandatory=$false)]
        [hashtable]$Preferences
    )

    # Always use the current preferences if none provided
    if ($null -eq $Preferences) {
        $Preferences = $script:prefs
    }

    $preferencesPath = "$env:USERPROFILE\Documents\PowerShell\Preferences.json"
    try {
        # Convert the hashtable to JSON and save it
        $Preferences | ConvertTo-Json -Depth 5 | Set-Content -Path $preferencesPath -Force
        Write-Verbose "Preferences saved to $preferencesPath"
    } catch {
        Write-Error "Failed to save preferences to $preferencesPath. Error: $($_.Exception.Message)"
    }
}

# Create alias to maintain backward compatibility with code that might call Save-Preferences
Set-Alias -Name Save-Preferences -Value Save-UserPreferences

# Initialize preferences with simplified loading
$preferencesPath = "$env:USERPROFILE\Documents\PowerShell\Preferences.json"
$script:prefs = @{
    Theme = "M365Princess"
    ShowGreeting = $true
    EditorPreference = $null
    LastUpdateCheck = (Get-Date).ToString('yyyy-MM-dd')
}

# Load existing preferences if available
if (Test-Path $preferencesPath) {
    try {
        $loadedPrefs = Get-Content -Path $preferencesPath -Raw | ConvertFrom-Json
        
        # Manually copy properties to avoid PS object conversion issues
        if ($loadedPrefs.Theme) { $script:prefs.Theme = $loadedPrefs.Theme }
        if ($null -ne $loadedPrefs.ShowGreeting) { $script:prefs.ShowGreeting = $loadedPrefs.ShowGreeting }
        if ($null -ne $loadedPrefs.EditorPreference) { $script:prefs.EditorPreference = $loadedPrefs.EditorPreference }
        if ($loadedPrefs.LastUpdateCheck) { $script:prefs.LastUpdateCheck = $loadedPrefs.LastUpdateCheck }
        
        # Add custom settings
        if ($loadedPrefs.CustomSettings) {
            $script:prefs.CustomSettings = @{}
            $loadedPrefs.CustomSettings.PSObject.Properties | ForEach-Object {
                $script:prefs.CustomSettings[$_.Name] = $_.Value
            }
        }
        
        # Add git settings
        if ($loadedPrefs.GitSettings) {
            $script:prefs.GitSettings = @{}
            $loadedPrefs.GitSettings.PSObject.Properties | ForEach-Object {
                $script:prefs.GitSettings[$_.Name] = $_.Value
            }
        }
    } catch {
        Write-Warning "Could not load preferences. Using defaults. Error: $_"
        # Keep using the default preferences we set above
    }
} else {
    Save-UserPreferences $script:prefs
}
#endregion

#region MODULE IMPORTS
# Add PowerShell module paths to ensure both casing variations are included
$env:PSModulePath = "$env:PSModulePath;$env:USERPROFILE\scoop\modules"
$env:PSModulePath = "$env:PSModulePath;$env:USERPROFILE\Documents\PowerShell\Modules"
$env:PSModulePath = "$env:PSModulePath;$env:USERPROFILE\Documents\Powershell\Modules"

# Import Chocolatey profile if available
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}
#endregion

#region SYSTEM MANAGEMENT FUNCTIONS
<#
.SYNOPSIS
    Checks for and updates PowerShell to the latest version
.DESCRIPTION
    Queries the PowerShell GitHub repository for the latest release and
    updates using winget if a newer version is available
.EXAMPLE
    Update-PowerShell
#>
function Update-PowerShell {
    [CmdletBinding()]
    param(
        # Set -Prerelease to allow checking prerelease builds (install still uses the stable winget package).
        [switch]$Prerelease
    )

    try {
        # Must be elevated for winget to update system-wide PowerShell
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isAdmin) {
            Write-Warning "Update-PowerShell requires an elevated shell (Run as administrator)."
            Write-Host  "Right-click PowerShell and choose 'Run as administrator', then run Update-PowerShell again." -ForegroundColor Yellow
            return
        }

        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Error "winget not found. Install 'App Installer' from the Microsoft Store, then try again."
            return
        }

        Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan

        $currentVersion = [version]$PSVersionTable.PSVersion
        $headers = @{
            "User-Agent" = "Update-PowerShell-Profile-Function"
            "Accept"     = "application/vnd.github+json"
        }

        $url = if ($Prerelease) {
            # First item from releases list (includes prereleases)
            "https://api.github.com/repos/PowerShell/PowerShell/releases?per_page=1"
        } else {
            # Latest stable release
            "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        }

        $release = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        $tag = if ($Prerelease) { $release[0].tag_name } else { $release.tag_name }
        $latestVersion = [version]($tag.TrimStart('v'))

        if ($currentVersion -lt $latestVersion) {
            Write-Host "Update available: current $currentVersion  →  latest $latestVersion" -ForegroundColor Yellow
            $args = @(
                'upgrade','--id','Microsoft.PowerShell','-e',
                '--accept-source-agreements','--accept-package-agreements'
            )
            Write-Host "Running: winget $($args -join ' ')" -ForegroundColor DarkGray

            $proc = Start-Process -FilePath 'winget' -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
            if ($proc.ExitCode -eq 0) {
                Write-Host "PowerShell has been updated. Close and reopen your shell to use $latestVersion." -ForegroundColor Magenta
            } else {
                Write-Error "winget exited with code $($proc.ExitCode). Check the console output above for details."
            }
        } else {
            Write-Host "Your PowerShell is up to date ($currentVersion)." -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to update PowerShell. $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Clears various system caches
.DESCRIPTION
    Clears Windows Prefetch, Temp folders, and IE cache to free up disk space
.EXAMPLE
    Clear-Cache
#>
function Clear-Cache {
    Write-Host "Clearing cache..." -ForegroundColor Cyan

    # Clear Windows Prefetch
    Write-Host "Clearing Windows Prefetch..." -ForegroundColor Yellow
    Remove-Item -Path "$env:SystemRoot\Prefetch\*" -Force -ErrorAction SilentlyContinue

    # Clear Windows Temp
    Write-Host "Clearing Windows Temp..." -ForegroundColor Yellow
    Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

    # Clear User Temp
    Write-Host "Clearing User Temp..." -ForegroundColor Yellow
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

    # Clear Internet Explorer Cache
    Write-Host "Clearing Internet Explorer Cache..." -ForegroundColor Yellow
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Cache clearing completed." -ForegroundColor Green
}

<#
.SYNOPSIS
    Displays system uptime in a human-readable format
.DESCRIPTION
    Calculates and displays the system's uptime based on the last boot time
.EXAMPLE
    uptime
#>
function uptime {
    try {
        # check powershell version
        if ($PSVersionTable.PSVersion.Major -eq 5) {
            $lastBoot = (Get-WmiObject win32_operatingsystem).LastBootUpTime
            $bootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($lastBoot)
        } else {
            $lastBootStr = net statistics workstation | Select-String "since" | ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
            # check date format
            if ($lastBootStr -match '^\d{2}/\d{2}/\d{4}') {
                $dateFormat = 'dd/MM/yyyy'
            } elseif ($lastBootStr -match '^\d{2}-\d{2}-\d{4}') {
                $dateFormat = 'dd-MM-yyyy'
            } elseif ($lastBootStr -match '^\d{4}/\d{2}/\d{2}') {
                $dateFormat = 'yyyy/MM/dd'
            } elseif ($lastBootStr -match '^\d{4}-\d{2}-\d{2}') {
                $dateFormat = 'yyyy-MM-dd'
            } elseif ($lastBootStr -match '^\d{2}\.\d{2}\.\d{4}') {
                $dateFormat = 'dd.MM.yyyy'
            }
            
            # check time format
            if ($lastBootStr -match '\bAM\b' -or $lastBootStr -match '\bPM\b') {
                $timeFormat = 'h:mm:ss tt'
            } else {
                $timeFormat = 'HH:mm:ss'
            }

            $bootTime = [System.DateTime]::ParseExact($lastBootStr, "$dateFormat $timeFormat", [System.Globalization.CultureInfo]::InvariantCulture)
        }

        # Format the start time
        $formattedBootTime = $bootTime.ToString("dddd, MMMM dd, yyyy HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture) + " [$lastBootStr]"
        Write-Host "System started on: $formattedBootTime" -ForegroundColor DarkGray

        # calculate uptime
        $uptime = (Get-Date) - $bootTime

        # Uptime in days, hours, minutes, and seconds
        $days = $uptime.Days
        $hours = $uptime.Hours
        $minutes = $uptime.Minutes
        $seconds = $uptime.Seconds

        # Uptime output
        Write-Host ("Uptime: {0} days, {1} hours, {2} minutes, {3} seconds" -f $days, $hours, $minutes, $seconds) -ForegroundColor Blue
    } catch {
        Write-Error "An error occurred while retrieving system uptime."
    }
}

<#
.SYNOPSIS
    Launches a command with administrator privileges
.DESCRIPTION
    Opens Windows Terminal as administrator and optionally runs a command
.PARAMETER args
    Optional command to run with elevated privileges
.EXAMPLE
    admin
    admin Get-Service -Name 'WinRM'
#>
function admin {
    if ($args.Count -gt 0) {
        $argList = $args -join ' '
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
    } else {
        Start-Process wt -Verb runAs
    }
}
# Set UNIX-like alias for the admin command
Set-Alias -Name su -Value admin

<#
.SYNOPSIS
    Displays detailed system information
.DESCRIPTION
    Shortcut for Get-ComputerInfo to show system details
.EXAMPLE
    sysinfo
#>
function sysinfo { Get-ComputerInfo }

<#
.SYNOPSIS
    Reloads the PowerShell profile
.DESCRIPTION
    Re-executes the current user's profile to refresh settings
.EXAMPLE
    reload-profile
#>
function reload-profile {
    & $profile
}

<#
.SYNOPSIS
    Kills a process by name
.DESCRIPTION
    A simpler wrapper around Stop-Process that accepts a process name
.PARAMETER name
    Name of the process to kill
.EXAMPLE
    pkill notepad
#>
function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

<#
.SYNOPSIS
    Lists processes by name
.DESCRIPTION
    A simpler wrapper around Get-Process that filters by name
.PARAMETER name
    Name of the processes to list
.EXAMPLE
    pgrep chrome
#>
function pgrep($name) {
    Get-Process $name
}

# Quick process termination alias
function k9 { Stop-Process -Name $args[0] }
#endregion

#region UTILITY FUNCTIONS
<#
.SYNOPSIS
    Checks if a command exists
.DESCRIPTION
    Tests whether a command is available in the current session
.PARAMETER command
    The command to test for
.EXAMPLE
    Test-CommandExists git
#>
function Test-CommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

<#
.SYNOPSIS
    Locates executables in the PATH
.DESCRIPTION
    Searches for a command in all directories listed in PATH environment variable
.PARAMETER Command
    The command to search for
.EXAMPLE
    whereis git
#>
function whereis {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    # Get paths from environment variable and remove empty ones
    $paths = $env:Path -split ';' | Where-Object { $_ -ne '' }
    $extensions = $env:PATHEXT -split ';'

    $found = @()

    foreach ($path in $paths) {
        # Skip invalid paths
        if (-Not (Test-Path $path)) { continue }

        $fullPath = Join-Path -Path $path -ChildPath $Command
        if (Test-Path $fullPath) {
            $found += $fullPath
        }

        foreach ($ext in $extensions) {
            $fullPathExt = "$fullPath$ext"
            if (Test-Path $fullPathExt) {
                $found += $fullPathExt
            }
        }
    }

    if ($found.Count -gt 0) {
        $found | Sort-Object -Unique
    } else {
        Write-Host "INFO: Could not find files for the given pattern." -ForegroundColor Red
    }
}

<#
.SYNOPSIS
    Gets the command definition
.DESCRIPTION
    Shows the full path of a command, similar to UNIX which command
.PARAMETER name
    Name of the command to locate
.EXAMPLE
    which git
#>
function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

<#
.SYNOPSIS
    Sets an environment variable
.DESCRIPTION
    UNIX-style command to set an environment variable
.PARAMETER name
    The name of the environment variable
.PARAMETER value
    The value to assign
.EXAMPLE
    export PATH "$HOME/bin:$PATH"
#>
function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}
#endregion

#region FILE MANAGEMENT
<#
.SYNOPSIS
    Creates an empty file
.DESCRIPTION
    UNIX-style touch command to create a new file or update timestamp
.PARAMETER file
    Path to the file to create or update
.EXAMPLE
    touch newfile.txt
#>
function touch($file) { "" | Out-File $file -Encoding ASCII }

<#
.SYNOPSIS
    Finds files by name pattern
.DESCRIPTION
    Recursively searches for files matching a name pattern
.PARAMETER name
    The pattern to search for
.EXAMPLE
    ff "*.json"
#>
function ff($name) {
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.FullName)"
    }
}

<#
.SYNOPSIS
    Extracts a zip file to the current directory
.DESCRIPTION
    Unzips an archive file in the current working directory
.PARAMETER file
    The zip file to extract
.EXAMPLE
    unzip myarchive.zip
#>
function unzip ($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}

<#
.SYNOPSIS
    Uploads a file to a hastebin-like service
.DESCRIPTION
    Posts the content of a file to bin.christitus.com and returns the URL
.PARAMETER args
    Path to the file to upload
.EXAMPLE
    hb script.ps1
#>
function hb {
    if ($args.Length -eq 0) {
        Write-Error "No file path specified."
        return
    }
    
    $FilePath = $args[0]
    
    if (Test-Path $FilePath) {
        $Content = Get-Content $FilePath -Raw
    } else {
        Write-Error "File path does not exist."
        return
    }
    
    $uri = "http://bin.christitus.com/documents"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $Content -ErrorAction Stop
        $hasteKey = $response.key
        $url = "http://bin.christitus.com/$hasteKey"
        Set-Clipboard $url
        Write-Output $url
    } catch {
        Write-Error "Failed to upload the document. Error: $_"
    }
}

<#
.SYNOPSIS
    Searches for text in files
.DESCRIPTION
    UNIX-style grep command to search for patterns in files
.PARAMETER regex
    The regular expression to search for
.PARAMETER dir
    Optional directory to search in
.EXAMPLE
    grep "error" *.log
    cat file.txt | grep "warning"
#>
function grep($regex, $dir) {
    if ( $dir ) {
        Get-ChildItem $dir | select-string $regex
        return
    }
    $input | select-string $regex
}

<#
.SYNOPSIS
    Shows disk volume information
.DESCRIPTION
    UNIX-style df command to show disk space usage
.EXAMPLE
    df
#>
function df {
    get-volume
}

<#
.SYNOPSIS
    Replaces text in a file
.DESCRIPTION
    UNIX-style sed for simple text replacements
.PARAMETER file
    The file to modify
.PARAMETER find
    Text to find
.PARAMETER replace
    Text to replace with
.EXAMPLE
    sed "config.txt" "localhost" "127.0.0.1"
#>
function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

<#
.SYNOPSIS
    Shows the beginning of a file
.DESCRIPTION
    UNIX-style head command to display the first lines of a file
.PARAMETER Path
    Path to the file
.PARAMETER n
    Number of lines to show (default: 10)
.EXAMPLE
    head log.txt 20
#>
function head {
  param($Path, $n = 10)
  Get-Content $Path -Head $n
}

<#
.SYNOPSIS
    Shows the end of a file
.DESCRIPTION
    UNIX-style tail command to display the last lines of a file
.PARAMETER Path
    Path to the file
.PARAMETER n
    Number of lines to show (default: 10)
.PARAMETER f
    Whether to follow the file for new content
.EXAMPLE
    tail log.txt 20
    tail -f app.log
#>
function tail {
  param($Path, $n = 10, [switch]$f = $false)
  Get-Content $Path -Tail $n -Wait:$f
}

<#
.SYNOPSIS
    Creates a new file
.DESCRIPTION
    Quick shorthand to create a new empty file
.PARAMETER name
    Name of the file to create
.EXAMPLE
    nf script.ps1
#>
function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }

<#
.SYNOPSIS
    Moves an item to the Recycle Bin
.DESCRIPTION
    Sends a file or folder to the Recycle Bin instead of permanently deleting it
.PARAMETER path
    Path to the item to trash
.EXAMPLE
    trash old_file.txt
#>
function trash($path) {
    $fullPath = (Resolve-Path -Path $path).Path

    if (Test-Path $fullPath) {
        $item = Get-Item $fullPath

        if ($item.PSIsContainer) {
          # Handle directory
            $parentPath = $item.Parent.FullName
        } else {
            # Handle file
            $parentPath = $item.DirectoryName
        }

        $shell = New-Object -ComObject 'Shell.Application'
        $shellItem = $shell.NameSpace($parentPath).ParseName($item.Name)

        if ($item) {
            $shellItem.InvokeVerb('delete')
            Write-Host "Item '$fullPath' has been moved to the Recycle Bin."
        } else {
            Write-Host "Error: Could not find the item '$fullPath' to trash."
        }
    } else {
        Write-Host "Error: Item '$fullPath' does not exist."
    }
}
#endregion

#region NAVIGATION & DIRECTORY MANAGEMENT
<#
.SYNOPSIS
    Creates a directory and changes to it
.DESCRIPTION
    Creates a new directory if it doesn't exist and changes the current location to it
.PARAMETER dir
    Directory to create and navigate to
.EXAMPLE
    mkcd new-project
#>
function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }

<#
.SYNOPSIS
    Changes to Documents directory
.DESCRIPTION
    Navigates to the user's Documents folder
.EXAMPLE
    docs
#>
function docs { 
    $docs = if(([Environment]::GetFolderPath("MyDocuments"))) {([Environment]::GetFolderPath("MyDocuments"))} else {$HOME + "\Documents"}
    Set-Location -Path $docs
}

<#
.SYNOPSIS
    Changes to Desktop directory
.DESCRIPTION
    Navigates to the user's Desktop folder
.EXAMPLE
    dtop
#>
function dtop { 
    $dtop = if ([Environment]::GetFolderPath("Desktop")) {[Environment]::GetFolderPath("Desktop")} else {$HOME + "\Documents"}
    Set-Location -Path $dtop
}

# Enhanced directory listing
function la { Get-ChildItem -Path . -Force | Format-Table -AutoSize }
function ll { Get-ChildItem -Path . -Force -Hidden | Format-Table -AutoSize }
#endregion

#region NETWORK UTILITIES
<#
.SYNOPSIS
    Gets public IP address
.DESCRIPTION
    Retrieves the machine's public IP address from an external service
.EXAMPLE
    Get-PubIP
#>
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

<#
.SYNOPSIS
    Flushes DNS cache
.DESCRIPTION
    Clears the DNS resolver cache
.EXAMPLE
    flushdns
#>
function flushdns {
    Clear-DnsClientCache
    Write-Host "DNS has been flushed"
}
#endregion

#region WINDOWS UTILITIES
<#
.SYNOPSIS
    Opens WinUtil full-release
.DESCRIPTION
    Downloads and executes the latest WinUtil script
.EXAMPLE
    winutil
#>
function winutil {
    irm https://christitus.com/win | iex
}

<#
.SYNOPSIS
    Opens WinUtil pre-release
.DESCRIPTION
    Downloads and executes the latest WinUtil pre-release
.EXAMPLE
    winutildev
#>
function winutildev {
    irm https://christitus.com/windev | iex
}
#endregion

#region GIT SHORTCUTS
<#
.SYNOPSIS
    Git shortcuts for common operations
.DESCRIPTION
    Quick aliases for common git commands
#>
# Git status
function gs { git status }

# Git add all
function ga { git add . }

# Git push
function gp { git push }

# Navigate to GitHub directory
function g { __zoxide_z github }

# Git clone
function gcl { git clone "$args" }

# Git add and commit in one step
function gcom {
    git add .
    git commit -m "$args"
}

# Git add, commit and push in one step
function lazyg {
    git add .
    git commit -m "$args"
    git push
}
#endregion

#region CLIPBOARD UTILITIES
<#
.SYNOPSIS
    Copies text to clipboard
.DESCRIPTION
    Sets the Windows clipboard content to the provided text
.PARAMETER args
    Text to copy to clipboard
.EXAMPLE
    cpy "Text to copy"
#>
function cpy { Set-Clipboard $args[0] }

<#
.SYNOPSIS
    Pastes from clipboard
.DESCRIPTION
    Gets the current content of the Windows clipboard
.EXAMPLE
    pst
#>
function pst { Get-Clipboard }
#endregion

#region WORKMODE INTEGRATION
<#
.SYNOPSIS
    WorkMode Integration for Productivity Tracking
.DESCRIPTION
    Integrates WorkMode module for time tracking and website blocking
    to help improve productivity and focus during work sessions.
#>

# Import WorkMode module if available
$workModeModulePath = Join-Path $PSScriptRoot "WorkMode.psm1"
if (Test-Path $workModeModulePath) {
    try {
        Import-Module $workModeModulePath -Force -ErrorAction Stop
        Write-Host "WorkMode module loaded successfully!" -ForegroundColor Green
        Write-Host "Use 'work-on' to start focus time, 'work-off' for breaks" -ForegroundColor Cyan
    } catch {
        Write-Warning "Failed to load WorkMode module: $($_.Exception.Message)"
    }
}

# WorkMode prompt integration
$script:WorkModeStatus = $null

function Update-WorkModePromptStatus {
    if (Get-Command Get-WorkModeStatus -ErrorAction SilentlyContinue) {
        try {
            # Try to get current session info from WorkMode module
            $script:WorkModeStatus = Get-WorkModeStatus -ErrorAction SilentlyContinue
        } catch {
            $script:WorkModeStatus = $null
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

#region UI & EXPERIENCE CUSTOMIZATION
# Admin check for prompt customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

<#
.SYNOPSIS
    Customizes the PowerShell prompt
.DESCRIPTION
    Shows current path, admin status, and WorkMode status in the PowerShell prompt
.EXAMPLE
    The function is automatically called for each prompt
#>
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

# Set window title with PowerShell version and admin status
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

# Configure text editor based on available options
$EDITOR = if (Test-CommandExists nvim) { 'nvim' }
          elseif (Test-CommandExists pvim) { 'pvim' }
          elseif (Test-CommandExists vim) { 'vim' }
          elseif (Test-CommandExists vi) { 'vi' }
          elseif (Test-CommandExists code) { 'code' }
          elseif (Test-CommandExists notepad++) { 'notepad++' }
          elseif (Test-CommandExists sublime_text) { 'sublime_text' }
          else { 'notepad' }
Set-Alias -Name vim -Value $EDITOR

<#
.SYNOPSIS
    Opens the profile for editing
.DESCRIPTION
    Opens the PowerShell profile in the configured editor
.EXAMPLE
    Edit-Profile
#>
function Edit-Profile {
    vim $PROFILE
}
Set-Alias -Name ep -Value Edit-Profile

# Enhanced PSReadLine Configuration
$PSReadLineOptions = @{
    EditMode = 'Windows'
    HistoryNoDuplicates = $true
    HistorySearchCursorMovesToEnd = $true
    Colors = @{
        Command = '#87CEEB'  # SkyBlue (pastel)
        Parameter = '#98FB98'  # PaleGreen (pastel)
        Operator = '#FFB6C1'  # LightPink (pastel)
        Variable = '#DDA0DD'  # Plum (pastel)
        String = '#FFDAB9'  # PeachPuff (pastel)
        Number = '#B0E0E6'  # PowderBlue (pastel)
        Type = '#F0E68C'  # Khaki (pastel)
        Comment = '#D3D3D3'  # LightGray (pastel)
        Keyword = '#8367c7'  # Violet (pastel)
        Error = '#FF6347'  # Tomato (keeping it close to red for visibility)
    }
    PredictionSource = 'History'
    PredictionViewStyle = 'ListView'
    BellStyle = 'None'
}
Set-PSReadLineOption @PSReadLineOptions

# Custom key handlers for improved keyboard navigation
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

# Prevent sensitive information from being added to history
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    $hasSensitive = $sensitive | Where-Object { $line -match $_ }
    return ($null -eq $hasSensitive)
}

# Improved prediction settings
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -MaximumHistoryCount 10000

# Custom tab completion for common commands
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    $customCompletions = @{
        'git' = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
        'npm' = @('install', 'start', 'run', 'test', 'build')
        'deno' = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
    }
    
    $command = $commandAst.CommandElements[0].Value
    if ($customCompletions.ContainsKey($command)) {
        $customCompletions[$command] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
Register-ArgumentCompleter -Native -CommandName git, npm, deno -ScriptBlock $scriptblock

# Dotnet CLI tab completion
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock

<#
.SYNOPSIS
    Displays help for PowerShell profile functions
.DESCRIPTION
    Shows a comprehensive list of available commands and their descriptions
.EXAMPLE
    Show-Help
#>
function Show-Help {
    $helpText = @"
$($PSStyle.Foreground.Cyan)PowerShell Profile Help$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)

$($PSStyle.Foreground.BrightMagenta)Update-PowerShell$($PSStyle.Reset) - Checks for the latest PowerShell release and updates if a new version is available.

$($PSStyle.Foreground.BrightMagenta)Edit-Profile$($PSStyle.Reset) - Opens the current user's profile for editing using the configured editor.

$($PSStyle.Foreground.BrightMagenta)whereis$($PSStyle.Reset) <command> - Displays the path of the specified command.

$($PSStyle.Foreground.BrightMagenta)touch$($PSStyle.Reset) <file> - Creates a new empty file.

$($PSStyle.Foreground.BrightMagenta)ff$($PSStyle.Reset) <name> - Finds files recursively with the specified name.

$($PSStyle.Foreground.BrightMagenta)Get-PubIP$($PSStyle.Reset) - Retrieves the public IP address of the machine.

$($PSStyle.Foreground.BrightMagenta)winutil$($PSStyle.Reset) - Runs the latest WinUtil full-release script from Chris Titus Tech.

$($PSStyle.Foreground.BrightMagenta)winutildev$($PSStyle.Reset) - Runs the latest WinUtil pre-release script from Chris Titus Tech.

$($PSStyle.Foreground.BrightMagenta)uptime$($PSStyle.Reset) - Displays the system uptime.

$($PSStyle.Foreground.BrightMagenta)reload-profile$($PSStyleReset) - Reloads the current user's PowerShell profile.

$($PSStyle.Foreground.BrightMagenta)unzip$($PSStyle.Reset) <file> - Extracts a zip file to the current directory.

$($PSStyle.Foreground.BrightMagenta)hb$($PSStyle.Reset) <file> - Uploads the specified file's content to a hastebin-like service and returns the URL.

$($PSStyle.Foreground.BrightMagenta)grep$($PSStyle.Reset) <regex> [dir] - Searches for a regex pattern in files within the specified directory or from the pipeline input.

$($PSStyle.Foreground.BrightMagenta)df$($PSStyle.Reset) - Displays information about volumes.

$($PSStyle.Foreground.BrightMagenta)sed$($PSStyle.Reset) <file> <find> <replace> - Replaces text in a file.

$($PSStyle.Foreground.BrightMagenta)which$($PSStyle.Reset) <name> - Shows the path of the command.

$($PSStyle.Foreground.BrightMagenta)export$($PSStyle.Reset) <name> <value> - Sets an environment variable.

$($PSStyle.Foreground.BrightMagenta)pkill$($PSStyle.Reset) <name> - Kills processes by name.

$($PSStyle.Foreground.BrightMagenta)pgrep$($PSStyle.Reset) <name> - Lists processes by name.

$($PSStyle.Foreground.BrightMagenta)head$($PSStyle.Reset) <path> [n] - Displays the first n lines of a file (default 10).

$($PSStyle.Foreground.BrightMagenta)tail$($PSStyle.Reset) <path> [n] - Displays the last n lines of a file (default 10).

$($PSStyle.Foreground.BrightMagenta)nf$($PSStyle.Reset) <name> - Creates a new file with the specified name.

$($PSStyle.Foreground.BrightMagenta)mkcd$($PSStyle.Reset) <dir> - Creates and changes to a new directory.

$($PSStyle.Foreground.BrightMagenta)docs$($PSStyle.Reset) - Changes the current directory to the user's Documents folder.

$($PSStyle.Foreground.BrightMagenta)dtop$($PSStyle.Reset) - Changes the current directory to the user's Desktop folder.

$($PSStyle.Foreground.BrightMagenta)ep$($PSStyle.Reset) - Opens the profile for editing.

$($PSStyle.Foreground.BrightMagenta)k9$($PSStyle.Reset) <name> - Kills a process by name.

$($PSStyle.Foreground.BrightMagenta)la$($PSStyle.Reset) - Lists all files in the current directory with detailed formatting.

$($PSStyle.Foreground.BrightMagenta)ll$($PSStyle.Reset) - Lists all files, including hidden, in the current directory with detailed formatting.

$($PSStyle.Foreground.BrightMagenta)gs$($PSStyle.Reset) - Shortcut for 'git status'.

$($PSStyle.Foreground.BrightMagenta)ga$($PSStyle.Reset) - Shortcut for 'git add .'.

$($PSStyle.Foreground.BrightMagenta)gp$($PSStyle.Reset) - Shortcut for 'git push'.

$($PSStyle.Foreground.BrightMagenta)g$($PSStyle.Reset) - Changes to the GitHub directory.

$($PSStyle.Foreground.BrightMagenta)gcom$($PSStyle.Reset) <message> - Adds all changes and commits with the specified message.

$($PSStyle.Foreground.BrightMagenta)lazyg$($PSStyle.Reset) <message> - Adds all changes, commits with the specified message, and pushes to the remote repository.

$($PSStyle.Foreground.BrightMagenta)sysinfo$($PSStyle.Reset) - Displays detailed system information.

$($PSStyle.Foreground.BrightMagenta)flushdns$($PSStyle.Reset) - Clears the DNS cache.

$($PSStyle.Foreground.BrightMagenta)cpy$($PSStyle.Reset) <text> - Copies the specified text to the clipboard.

$($PSStyle.Foreground.BrightMagenta)pst$($PSStyle.Reset) - Retrieves text from the clipboard.

$($PSStyle.Foreground.BrightCyan)WorkMode Commands$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)-----------------$($PSStyle.Reset)
$($PSStyle.Foreground.BrightMagenta)work-on$($PSStyle.Reset) - Enables WorkMode (blocks distracting websites, starts work timer).
$($PSStyle.Foreground.BrightMagenta)work-off$($PSStyle.Reset) - Disables WorkMode (unblocks websites, starts break timer).
$($PSStyle.Foreground.BrightMagenta)work-status$($PSStyle.Reset) - Shows current WorkMode status and session information.
$($PSStyle.Foreground.BrightMagenta)work-stats$($PSStyle.Reset) - Displays productivity statistics and time tracking insights.
$($PSStyle.Foreground.BrightMagenta)work-history$($PSStyle.Reset) - Shows recent WorkMode session history.
$($PSStyle.Foreground.BrightMagenta)add-block-site$($PSStyle.Reset) <domain> - Adds a website to the WorkMode block list.
$($PSStyle.Foreground.BrightMagenta)remove-block-site$($PSStyle.Reset) <domain> - Removes a website from the WorkMode block list.
$($PSStyle.Foreground.BrightMagenta)show-block-sites$($PSStyle.Reset) - Lists all currently blocked websites.

$($PSStyle.Foreground.BrightCyan)FZF Commands$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)------------$($PSStyle.Reset)
$($PSStyle.Foreground.BrightMagenta)fzf-find$($PSStyle.Reset) - Interactively search for files in the current directory and subdirectories.
$($PSStyle.Foreground.BrightMagenta)fzf-cd$($PSStyle.Reset) - Change directory using interactive fuzzy search.
$($PSStyle.Foreground.BrightMagenta)fzf-history$($PSStyle.Reset) - Search and execute commands from your PowerShell history.
$($PSStyle.Foreground.BrightMagenta)fzf-kill$($PSStyle.Reset) - Interactively search and kill processes.
$($PSStyle.Foreground.BrightMagenta)Ctrl+T$($PSStyle.Reset) - Insert a file path at cursor position using FZF.
$($PSStyle.Foreground.BrightMagenta)Ctrl+R$($PSStyle.Reset) - Search command history with FZF.

Use '$($PSStyle.Foreground.Magenta)Show-Help$($PSStyle.Reset)' to display this help message.
"@
    Write-Host $helpText
}
#endregion

# #region INITIALIZATION & EXTERNAL MODULES
# # Install and import Terminal-Icons with minimal output (optimized loading)
# try {
#     # Attempt to import. If already imported, this is fast.
#     Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    
#     # Check if a key command from Terminal-Icons is available.
#     # If not, the module might not be installed or failed to import.
#     if (-not (Get-Command Set-TerminalIconsTheme -ErrorAction SilentlyContinue)) {
#         Write-Verbose "Terminal-Icons commands not found after initial import. Checking installation status."
        
#         # Check if the module is discoverable (this is the potentially slow part, run only if needed)
#         if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
#             Write-Host "Terminal-Icons module not installed. Attempting to install..." -ForegroundColor Yellow
#             # Install-Module will stop script if it fails due to -ErrorAction Stop
#             Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -ErrorAction Stop 
#             Write-Host "Terminal-Icons installed successfully." -ForegroundColor Green
#             Write-Host "Please restart PowerShell or import Terminal-Icons manually if icons don't appear in this session." -ForegroundColor Cyan
#             # Re-attempt import after install for the current session
#             Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
#         } else {
#             # Module is available (listed) but wasn't loaded by the first Import-Module or its commands aren't found.
#             # This could happen if it's installed but something is wrong, or if Get-Command check is somehow problematic.
#             # Try importing again explicitly.
#             Write-Verbose "Terminal-Icons module is available but commands were not found after initial import. Retrying import."
#             Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
#         }
#     }

#     # Silently try to set the theme if commands are now available
#     if (Get-Command Set-TerminalIconsTheme -ErrorAction SilentlyContinue) {
#         # The -ErrorAction SilentlyContinue on the cmdlets themselves handles suppression
#         Set-TerminalIconsTheme 'devblackops' -ErrorAction SilentlyContinue
#         Set-TerminalIconsIconTheme 'devblackops' -ErrorAction SilentlyContinue
#     }
# } catch { # Catches errors from Install-Module (due to -ErrorAction Stop) or other unexpected issues
#     Write-Warning "An error occurred during Terminal-Icons setup: $($_.Exception.Message)"
# }

# # Add a helper function to test Terminal-Icons without using Export-ModuleMember
# function Test-TerminalIcons {
#     Write-Host "Testing Terminal-Icons display capabilities..." -ForegroundColor Cyan
#     Write-Host "If you see file/folder icons in the output below, Terminal-Icons is working correctly." -ForegroundColor Cyan
#     Write-Host "Otherwise, make sure you're using a Nerd Font in your terminal settings." -ForegroundColor Cyan
#     Write-Host "-----------------------------------------------" -ForegroundColor Yellow
#     Get-ChildItem $HOME | Select-Object -First 5
#     Write-Host "-----------------------------------------------" -ForegroundColor Yellow
#     Write-Host "Recommended fonts: CascadiaCode NF, FiraCode NF, or Hack Nerd Font" -ForegroundColor Cyan
#     Write-Host "Font can be set in Windows Terminal Settings → Profiles → Default → Appearance → Font face" -ForegroundColor Cyan
# }

# Setup Oh-My-Posh with M365Princess theme (local cache with update logic)
$OmpThemeUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/M365Princess.omp.json"
$OmpThemeDir = "$env:USERPROFILE\Documents\PowerShell\Themes"
$OmpLocalThemePath = Join-Path -Path $OmpThemeDir -ChildPath "M365Princess.omp.json"
$OmpEffectiveThemePath = $OmpLocalThemePath # Default to local path

# Ensure theme directory exists
if (-not (Test-Path $OmpThemeDir)) {
    New-Item -ItemType Directory -Path $OmpThemeDir -Force -ErrorAction SilentlyContinue | Out-Null
}

$shouldDownloadOrUpdate = $false
if (Test-Path $OmpLocalThemePath) {
    # Check if the theme is older than 7 days
    try {
        $fileInfo = Get-Item $OmpLocalThemePath -ErrorAction Stop
        if ($fileInfo.LastWriteTime -lt (Get-Date).AddDays(-7)) {
            Write-Host "Oh My Posh theme cache is older than 7 days." -ForegroundColor DarkGray
            $shouldDownloadOrUpdate = $true
        }
    } catch {
        # Error accessing file info, perhaps corrupted, treat as if it needs download
        Write-Warning "Could not get info for cached Oh My Posh theme at $OmpLocalThemePath. Attempting re-download."
        $shouldDownloadOrUpdate = $true
    }
} else {
    # Theme does not exist locally
    $shouldDownloadOrUpdate = $true
}

if ($shouldDownloadOrUpdate) {
    $actionVerb = if (Test-Path $OmpLocalThemePath) { "Updating" } else { "Downloading" }
    Write-Host "$actionVerb Oh My Posh theme: M365Princess.omp.json..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $OmpThemeUrl -OutFile $OmpLocalThemePath -TimeoutSec 10 -ErrorAction Stop
        Write-Host "Theme $actionVerb successful to $OmpLocalThemePath" -ForegroundColor Green
        $OmpEffectiveThemePath = $OmpLocalThemePath # Ensure we use the newly downloaded/updated theme
    } catch {
        Write-Warning "Failed to $actionVerb Oh My Posh theme. Error: $($_.Exception.Message)"
        if (-not (Test-Path $OmpLocalThemePath)) {
            # If download/update failed AND local file still doesn't exist (i.e., initial download failed or local file was corrupt/deleted)
            Write-Warning "Falling back to URL for Oh My Posh theme."
            $OmpEffectiveThemePath = $OmpThemeUrl
        } else {
            # Download/update failed, but a (possibly stale) local file exists. Use it.
            Write-Host "Using existing cached Oh My Posh theme at $OmpLocalThemePath." -ForegroundColor Yellow
            $OmpEffectiveThemePath = $OmpLocalThemePath
        }
    }
}

# Final check: if OmpEffectiveThemePath is set to local but file doesn't exist (e.g. dir creation failed, or some other edge case)
if ($OmpEffectiveThemePath -ne $OmpThemeUrl -and (-not (Test-Path $OmpEffectiveThemePath))) {
    Write-Warning "Local Oh My Posh theme specified at '$OmpEffectiveThemePath' not found. Falling back to URL."
    $OmpEffectiveThemePath = $OmpThemeUrl
}

oh-my-posh init pwsh --config "$OmpEffectiveThemePath" | Invoke-Expression

# Initialize zoxide (directory jumper)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
} else {
    Write-Host "zoxide command not found. Attempting to install via winget..."
    try {
        winget install -e --id ajeetdsouza.zoxide
        Write-Host "zoxide installed successfully. Initializing..."
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    } catch {
        Write-Error "Failed to install zoxide. Error: $_"
    }
}

Set-Alias -Name z -Value __zoxide_z -Option AllScope -Scope Global -Force
Set-Alias -Name zi -Value __zoxide_zi -Option AllScope -Scope Global -Force

# Load user custom scripts if they exist
if (Test-Path "$PSScriptRoot\CTTcustom.ps1") {
    Invoke-Expression -Command "& `"$PSScriptRoot\CTTcustom.ps1`""
}

# Load GitHub Copilot CLI
Import-Module -Name Microsoft.WinGet.CommandNotFound
if (Test-Path "C:\Users\swfox\Documents\PowerShell\gh-copilot.ps1") {
    . "C:\Users\swfox\Documents\PowerShell\gh-copilot.ps1"
}

# Initialize FZF (Fuzzy Finder)
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    # Set FZF environment variables for configuration
    $env:FZF_DEFAULT_OPTS = "--height 40% --layout=reverse --border --inline-info --preview 'if [[ -d {} ]]; then ls -la {}; else cat {} 2>/dev/null || echo Binary file; fi'"

    # --- Define Exclusions ---
    # For Get-ChildItem's -Exclude parameter (expects simple wildcards)
    $script:FzfExcludedPatterns_GCI = @(
        ".*", # Hidden files/dirs like .git, .vscode, .cache
        "node_modules", "vendor", "target", "build", "dist", "obj",
        "\$RECYCLE.BIN", "System Volume Information",
        "__pycache__", "*.pyc",
        "*.tmp", "*.bak", "*.swp" # Common temp/backup files
    )
    # For rg's --glob parameter (expects gitignore-style globs)
    $script:FzfExcludedGlobs_RG = @(
        '!.git/',      # Specifically .git directory
        '!.*',         # Other dotfiles/dot-directories at any depth component
        '!node_modules/', '!vendor/', '!target/', '!build/', '!dist/', '!obj/',
        '!\$RECYCLE.BIN/', '!System Volume Information/',
        '!__pycache__/', '!*.pyc',
        '!*.tmp', '!*.bak', '!*.swp'
    )

    # --- Set FZF_DEFAULT_COMMAND (for Ctrl+T and Find-Fzf file searching) ---
    if (Get-Command rg -ErrorAction SilentlyContinue) {
        $rgExcludeGlobString = (($script:FzfExcludedGlobs_RG | ForEach-Object { "--glob ""$_""" }) -join ' ')
        # rg searches for files, includes hidden, follows symlinks, applies exclusions
        $env:FZF_DEFAULT_COMMAND = "rg --files --hidden --follow $rgExcludeGlobString"
    } else {
        # Fallback to Get-ChildItem for file searching
        $gciExcludeArrayString = "'" + ($script:FzfExcludedPatterns_GCI -join "','") + "'"
        # Get-ChildItem searches for files, includes hidden (-Force), applies exclusions
        $env:FZF_DEFAULT_COMMAND = "Get-ChildItem -Recurse -File -Force -Exclude @($gciExcludeArrayString) -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName"
    }
    $env:FZF_CTRL_T_COMMAND = $env:FZF_DEFAULT_COMMAND
    
    # PSReadLine key bindings for FZF integration
    Set-PSReadLineKeyHandler -Key Ctrl+t -ScriptBlock {
        $result = $null
        try {
            # fzf will use $env:FZF_CTRL_T_COMMAND
            $result = Invoke-Expression "fzf" | Out-String
        } catch {
            # Do nothing on error
        }
        if (-not [string]::IsNullOrEmpty($result)) {
            $result = $result.Trim()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("`"$result`"")
        }
    }
    
    # Ctrl+R for history search with FZF
    Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock {
        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        
        try {
            $history = Get-Content (Get-PSReadLineOption).HistorySavePath -ErrorAction Stop
            $history = $history | Where-Object { $_ -ne "" } | Select-Object -Unique
            
            $selection = $history | Out-String | fzf --reverse --height 40% # Consider adding --no-sort if order is important
            
            if (-not [string]::IsNullOrEmpty($selection)) {
                [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selection.Trim())
            }
        } catch {
            Write-Host "Error: $_" -ForegroundColor Red
        }
    }
    
    # FZF helper functions
    
    <#
    .SYNOPSIS
        Search for files with FZF using refined exclusions.
    .DESCRIPTION
        Uses FZF to interactively search for files, leveraging the centrally defined
        FZF_DEFAULT_COMMAND which includes common clutter exclusions.
    .EXAMPLE
        Find-Fzf
    #>
    function Find-Fzf {
        # Uses the pre-configured FZF_DEFAULT_COMMAND (rg or Get-ChildItem based)
        Invoke-Expression "$($env:FZF_DEFAULT_COMMAND) | fzf"
    }
    
    <#
    .SYNOPSIS
        Change directory using FZF with refined exclusions.
    .DESCRIPTION
        Interactively search for directories and navigate to the selected one,
        excluding common clutter and dot-directories.
    .EXAMPLE
        cd-fzf
    #>
    function cd-fzf {
        # For directory search, use Get-ChildItem -Directory
        # $script:FzfExcludedPatterns_GCI is used for -Exclude
        # -Force includes hidden directories (like .config), then ".*" in ExcludedPatterns filters .git etc.
        $gciExcludeDirArrayString = "'" + ($script:FzfExcludedPatterns_GCI -join "','") + "'"
        $gciDirCommand = "Get-ChildItem -Directory -Recurse -Depth 5 -Force -Exclude @($gciExcludeDirArrayString) -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName"
        $selectedDir = Invoke-Expression "$gciDirCommand | fzf"
        if ($selectedDir) {
            Set-Location $selectedDir.Trim() # Ensure no trailing spaces/newlines
        }
    }
    
    <#
    .SYNOPSIS
        Search command history with FZF
    .DESCRIPTION
        Uses FZF to interactively search through PowerShell command history
    .EXAMPLE
        History-Fzf
    #>
    function History-Fzf {
        $history = Get-Content (Get-PSReadLineOption).HistorySavePath -ErrorAction SilentlyContinue
        $command = $history | Where-Object { $_ -ne "" } | Select-Object -Unique | fzf --tac --no-sort
        if ($command) {
            Invoke-Expression $command.Trim() # Ensure no trailing spaces/newlines
        }
    }
    
    <#
    .SYNOPSIS
        Search and kill processes with FZF
    .DESCRIPTION
        Interactively search for running processes and kill the selected one
    .EXAMPLE
        Kill-Fzf
    #>
    function Kill-Fzf {
        $processLines = Get-Process | Where-Object { $_.Name -ne "System" -and $_.Name -ne "Idle" } | 
            Sort-Object -Property CPU -Descending |
            Format-Table -AutoSize Id, Name, CPU, WorkingSet, Description | 
            Out-String
        
        # FZF expects input strings, Format-Table output is good
        $selectedProcessString = $processLines | fzf --header-lines=3 --multi --reverse
        
        if ($selectedProcessString) {
            # Process multiple selections if --multi is used effectively
            $selectedProcessString.Split([System.Environment]::NewLine) | ForEach-Object {
                $line = $_.Trim()
                if ($line) {
                    # Attempt to parse the ID from the formatted line (usually the first element)
                    $processIdString = ($line -split "\s+")[0] # Get the first block of non-whitespace
                    if ($processIdString -match "^\d+$") {
                        $processId = [int]$processIdString
                        try {
                            Stop-Process -Id $processId -Force -Confirm:$false -ErrorAction Stop # Confirm can be annoying here
                            Write-Host "Process $processId killed." -ForegroundColor Green
                        } catch {
                            Write-Warning "Failed to kill process $processId. Error: $($_.Exception.Message)"
                        }
                    }
                }
            }
        }
    }
    
    # Create aliases for FZF helper functions
    Set-Alias -Name fzf-find -Value Find-Fzf
    Set-Alias -Name fzf-cd -Value cd-fzf
    Set-Alias -Name fzf-history -Value History-Fzf
    Set-Alias -Name fzf-kill -Value Kill-Fzf
    
    # Add to help documentation in Show-Help function
    # You can update Show-Help function separately
    
    Write-Host "FZF initialized with refined exclusions. Use Ctrl+T (files) and Ctrl+R (history)." -ForegroundColor Cyan -BackgroundColor DarkGray
} else {
    Write-Warning "FZF not found in PATH. Install FZF for enhanced fuzzy finding capabilities."
    Write-Host "  To install: winget install fzf or choco install fzf" -ForegroundColor Yellow
}
#endregion

# Show help tip on startup
Write-Host "$($PSStyle.Foreground.BrightMagenta)Use 'Show-Help' to display help$($PSStyle.Reset)"

# Clear the console
Clear-Host

# Run neofetch if there is enough horizontal space
if (($Host.UI.RawUI.WindowSize.Width -gt 80) -and ($Host.UI.RawUI.WindowSize.Height -gt 20)) {
    neofetch
}
