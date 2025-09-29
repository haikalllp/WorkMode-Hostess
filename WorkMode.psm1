###############################################################################
#                                                                             #
#                           WorkMode Module                                   #
#                                                                             #
#         A PowerShell productivity module for time tracking and               #
#         website blocking during work sessions using hostess                 #
#                                                                             #
#                               Version 1.0                                   #
#                                                                             #
###############################################################################

#region Module Variables and Configuration

# Module configuration
$script:WorkModeConfig = @{
    DataDir = "$env:USERPROFILE\Documents\PowerShell\WorkMode"
    TimeTrackingFile = "time-tracking.json"
    SitesConfigFile = "work-sites.json"
    HostessPath = "$PSScriptRoot\hostess.exe"
    BlockIP = "127.0.0.1"
    WorkHoursStart = 9
    WorkHoursEnd = 17
    ModuleVersion = "1.0.0"
    GitHubRepo = "cbednarski/hostess"
    GitHubApiUrl = "https://api.github.com/repos/$($script:WorkModeConfig.GitHubRepo)/releases/latest"
}

# Current session state
$script:CurrentSession = @{
    Mode = "Normal"  # Work or Normal
    StartTime = $null
    SessionId = [Guid]::NewGuid().ToString()
}

# Default distracting websites to block
$script:DefaultBlockSites = @(
    "facebook.com", "www.facebook.com", "fb.com",
    "twitter.com", "www.twitter.com", "x.com",
    "instagram.com", "www.instagram.com",
    "youtube.com", "www.youtube.com", "youtu.be",
    "tiktok.com", "www.tiktok.com",
    "reddit.com", "www.reddit.com", "old.reddit.com",
    "netflix.com", "www.netflix.com",
    "instagram.com", "www.instagram.com",
    "snapchat.com", "www.snapchat.com",
    "linkedin.com", "www.linkedin.com",
    "pinterest.com", "www.pinterest.com",
    "tumblr.com", "www.tumblr.com",
    "imgur.com", "www.imgur.com",
    "twitch.tv", "www.twitch.tv",
    "discord.com", "www.discord.com",
    "steam.com", "www.steam.com",
    "epic.games.com", "www.epic.games.com"
)

# Initialize data directory
function Initialize-WorkModeData {
    if (-not (Test-Path $script:WorkModeConfig.DataDir)) {
        New-Item -ItemType Directory -Path $script:WorkModeConfig.DataDir -Force | Out-Null
    }

    $timeTrackingPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.TimeTrackingFile
    $sitesConfigPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.SitesConfigFile

    # Initialize time tracking file if it doesn't exist
    if (-not (Test-Path $timeTrackingPath)) {
        @{
            Sessions = @()
            CurrentSession = $null
            Version = "1.0"
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $timeTrackingPath
    }

    # Initialize sites configuration if it doesn't exist
    if (-not (Test-Path $sitesConfigPath)) {
        @{
            BlockSites = $script:DefaultBlockSites
            CustomSites = @()
            Version = "1.0"
            LastUpdated = (Get-Date).ToString("o")
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $sitesConfigPath
    }
}

#endregion

#region Core WorkMode Functions

<#
.SYNOPSIS
    Enables WorkMode by blocking distracting websites and starting time tracking.
.DESCRIPTION
    Switches to WorkMode by enabling hostess entries for distracting websites
    and begins tracking time spent in productive work mode.
.EXAMPLE
    Enable-WorkMode
.EXAMPLE
    work-on
#>
function Enable-WorkMode {
    [CmdletBinding()]
    [Alias("work-on")]
    param()

    # Check if already in work mode
    if ($script:CurrentSession.Mode -eq "Work") {
        Write-Host "Already in WorkMode!" -ForegroundColor Yellow
        Get-WorkModeStatus
        return
    }

    Write-Host "🔴 Enabling WorkMode..." -ForegroundColor Red

    try {
        # End current normal session if active
        if ($script:CurrentSession.StartTime) {
            Complete-Session -Mode $script:CurrentSession.Mode
        }

        # Block distracting websites
        Enable-WorkSitesBlocking

        # Start new work session
        $script:CurrentSession.Mode = "Work"
        $script:CurrentSession.StartTime = Get-Date
        $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()

        Write-Host "✅ WorkMode enabled - Distractions blocked!" -ForegroundColor Green
        Write-Host "Focus time started at: $($script:CurrentSession.StartTime.ToString('HH:mm:ss'))" -ForegroundColor Cyan

        # Update prompt
        Update-WorkModePrompt

    } catch {
        Write-Error "Failed to enable WorkMode: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Disables WorkMode by unblocking websites and switching to normal mode tracking.
.DESCRIPTION
    Switches to NormalMode by disabling hostess entries for distracting websites
    and begins tracking time spent in normal (distracted) mode.
.EXAMPLE
    Disable-WorkMode
.EXAMPLE
    work-off
#>
function Disable-WorkMode {
    [CmdletBinding()]
    [Alias("work-off")]
    param()

    # Check if already in normal mode
    if ($script:CurrentSession.Mode -eq "Normal") {
        Write-Host "Already in NormalMode!" -ForegroundColor Yellow
        Get-WorkModeStatus
        return
    }

    Write-Host "🟢 Disabling WorkMode..." -ForegroundColor Green

    try {
        # End current work session if active
        if ($script:CurrentSession.StartTime) {
            Complete-Session -Mode $script:CurrentSession.Mode
        }

        # Unblock distracting websites
        Disable-WorkSitesBlocking

        # Start new normal session
        $script:CurrentSession.Mode = "Normal"
        $script:CurrentSession.StartTime = Get-Date
        $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()

        Write-Host "✅ NormalMode enabled - Websites accessible!" -ForegroundColor Green
        Write-Host "Break time started at: $($script:CurrentSession.StartTime.ToString('HH:mm:ss'))" -ForegroundColor Cyan

        # Update prompt
        Update-WorkModePrompt

    } catch {
        Write-Error "Failed to disable WorkMode: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Shows the current WorkMode status and session information.
.DESCRIPTION
    Displays information about the current mode, session duration,
    and provides a quick overview of productivity statistics.
.EXAMPLE
    Get-WorkModeStatus
.EXAMPLE
    work-status
#>
function Get-WorkModeStatus {
    [CmdletBinding()]
    [Alias("work-status")]
    param()

    # Ensure data is initialized
    Initialize-WorkModeData

    $modeIcon = if ($script:CurrentSession.Mode -eq "Work") { "🔴" } else { "🟢" }
    $modeColor = if ($script:CurrentSession.Mode -eq "Work") { "Red" } else { "Green" }

    Write-Host "=== WorkMode Status ===" -ForegroundColor Cyan
    Write-Host "Current Mode: $modeIcon $($script:CurrentSession.Mode)" -ForegroundColor $modeColor

    if ($script:CurrentSession.StartTime) {
        $duration = (Get-Date) - $script:CurrentSession.StartTime
        $durationStr = Format-Duration $duration
        Write-Host "Session Started: $($script:CurrentSession.StartTime.ToString('HH:mm:ss'))" -ForegroundColor White
        Write-Host "Session Duration: $durationStr" -ForegroundColor White
    } else {
        Write-Host "No active session" -ForegroundColor Yellow
    }

    # Show today's quick stats
    $todayStats = Get-TodayStats
    if ($todayStats) {
        Write-Host "Today's Work Time: $($todayStats.WorkTime)" -ForegroundColor Green
        Write-Host "Today's Normal Time: $($todayStats.NormalTime)" -ForegroundColor Yellow
        Write-Host "Work Percentage: $($todayStats.WorkPercentage)%" -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "Use 'work-on' to start focus time or 'work-off' for break time" -ForegroundColor White
}

#endregion

#region Time Tracking Functions

<#
.SYNOPSIS
    Completes the current session and saves it to the tracking file.
.DESCRIPTION
    Internal function to end the current session, calculate duration,
    and persist the session data to the time tracking file.
.PARAMETER Mode
    The mode of the session being completed (Work or Normal)
#>
function Complete-Session {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Work", "Normal")]
        [string]$Mode
    )

    if (-not $script:CurrentSession.StartTime) {
        return
    }

    $endTime = Get-Date
    $duration = $endTime - $script:CurrentSession.StartTime

    $sessionData = @{
        SessionId = $script:CurrentSession.SessionId
        Mode = $Mode
        StartTime = $script:CurrentSession.StartTime.ToString("o")
        EndTime = $endTime.ToString("o")
        DurationMinutes = [Math]::Round($duration.TotalMinutes, 2)
        DurationHours = [Math]::Round($duration.TotalHours, 2)
        Date = $script:CurrentSession.StartTime.ToString("yyyy-MM-dd")
        DayOfWeek = $script:CurrentSession.StartTime.DayOfWeek.ToString()
    }

    # Load existing data
    $timeTrackingPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.TimeTrackingFile
    $data = Get-Content -Path $timeTrackingPath -Raw | ConvertFrom-Json

    # Add session
    $data.Sessions += $sessionData
    $data.CurrentSession = $null

    # Save updated data
    $data | ConvertTo-Json -Depth 10 | Set-Content -Path $timeTrackingPath

    # Reset current session
    $script:CurrentSession.StartTime = $null
    $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()
}

<#
.SYNOPSIS
    Gets productivity statistics and analytics.
.DESCRIPTION
    Displays comprehensive productivity statistics including work vs normal time,
    daily/weekly breakdowns, and productivity insights.
.EXAMPLE
    Get-ProductivityStats
.EXAMPLE
    work-stats
#>
function Get-ProductivityStats {
    [CmdletBinding()]
    [Alias("work-stats")]
    param()

    Initialize-WorkModeData

    $timeTrackingPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.TimeTrackingFile
    $data = Get-Content -Path $timeTrackingPath -Raw | ConvertFrom-Json

    if (-not $data.Sessions -or $data.Sessions.Count -eq 0) {
        Write-Host "No sessions found. Start tracking with 'work-on' or 'work-off'" -ForegroundColor Yellow
        return
    }

    Write-Host "=== Productivity Statistics ===" -ForegroundColor Cyan
    Write-Host ""

    # Overall statistics
    $totalSessions = $data.Sessions.Count
    $workSessions = $data.Sessions | Where-Object { $_.Mode -eq "Work" }
    $normalSessions = $data.Sessions | Where-Object { $_.Mode -eq "Normal" }

    $totalWorkHours = ($workSessions | Measure-Object -Property DurationHours -Sum).Sum
    $totalNormalHours = ($normalSessions | Measure-Object -Property DurationHours -Sum).Sum
    $totalHours = $totalWorkHours + $totalNormalHours

    $workPercentage = if ($totalHours -gt 0) { [Math]::Round(($totalWorkHours / $totalHours) * 100, 1) } else { 0 }

    Write-Host "📊 Overall Statistics" -ForegroundColor White
    Write-Host "Total Sessions: $totalSessions" -ForegroundColor White
    Write-Host "Total Work Time: $([Math]::Round($totalWorkHours, 1)) hours" -ForegroundColor Green
    Write-Host "Total Normal Time: $([Math]::Round($totalNormalHours, 1)) hours" -ForegroundColor Yellow
    Write-Host "Work Percentage: $workPercentage%" -ForegroundColor Cyan
    Write-Host ""

    # Today's statistics
    $today = Get-Date
    $todayStr = $today.ToString("yyyy-MM-dd")
    $todaySessions = $data.Sessions | Where-Object { $_.Date -eq $todayStr }

    if ($todaySessions) {
        $todayWorkHours = ($todaySessions | Where-Object { $_.Mode -eq "Work" } | Measure-Object -Property DurationHours -Sum).Sum
        $todayNormalHours = ($todaySessions | Where-Object { $_.Mode -eq "Normal" } | Measure-Object -Property DurationHours -Sum).Sum
        $todayWorkPercentage = if (($todayWorkHours + $todayNormalHours) -gt 0) {
            [Math]::Round(($todayWorkHours / ($todayWorkHours + $todayNormalHours)) * 100, 1)
        } else { 0 }

        Write-Host "📅 Today's Statistics ($todayStr)" -ForegroundColor White
        Write-Host "Work Time: $([Math]::Round($todayWorkHours, 1)) hours" -ForegroundColor Green
        Write-Host "Normal Time: $([Math]::Round($todayNormalHours, 1)) hours" -ForegroundColor Yellow
        Write-Host "Work Percentage: $todayWorkPercentage%" -ForegroundColor Cyan
        Write-Host ""
    }

    # This week's statistics
    $weekStart = $today.AddDays(-($today.DayOfWeek.value__))
    $weekSessions = $data.Sessions | Where-Object {
        [DateTime]$_.Date -ge $weekStart
    }

    if ($weekSessions) {
        $weekWorkHours = ($weekSessions | Where-Object { $_.Mode -eq "Work" } | Measure-Object -Property DurationHours -Sum).Sum
        $weekNormalHours = ($weekSessions | Where-Object { $_.Mode -eq "Normal" } | Measure-Object -Property DurationHours -Sum).Sum
        $weekWorkPercentage = if (($weekWorkHours + $weekNormalHours) -gt 0) {
            [Math]::Round(($weekWorkHours / ($weekWorkHours + $weekNormalHours)) * 100, 1)
        } else { 0 }

        Write-Host "📆 This Week's Statistics" -ForegroundColor White
        Write-Host "Work Time: $([Math]::Round($weekWorkHours, 1)) hours" -ForegroundColor Green
        Write-Host "Normal Time: $([Math]::Round($weekNormalHours, 1)) hours" -ForegroundColor Yellow
        Write-Host "Work Percentage: $weekWorkPercentage%" -ForegroundColor Cyan
        Write-Host ""
    }

    # Current session info
    if ($script:CurrentSession.StartTime) {
        $currentDuration = (Get-Date) - $script:CurrentSession.StartTime
        $currentDurationStr = Format-Duration $currentDuration
        Write-Host "⏱️  Current Session" -ForegroundColor White
        Write-Host "Mode: $($script:CurrentSession.Mode)" -ForegroundColor $(if ($script:CurrentSession.Mode -eq "Work") { "Green" } else { "Yellow" })
        Write-Host "Duration: $currentDurationStr" -ForegroundColor White
    }

    # Productivity insights
    Write-Host ""
    Write-Host "💡 Productivity Insights" -ForegroundColor Magenta
    if ($workPercentage -ge 70) {
        Write-Host "Excellent focus! You're maintaining great work habits." -ForegroundColor Green
    } elseif ($workPercentage -ge 50) {
        Write-Host "Good balance between work and breaks." -ForegroundColor Yellow
    } else {
        Write-Host "Consider increasing focus time for better productivity." -ForegroundColor Red
    }
}

<#
.SYNOPSIS
    Shows the history of WorkMode sessions.
.DESCRIPTION
    Displays a chronological list of all WorkMode sessions with
    their duration, mode, and timestamps.
.EXAMPLE
    Get-WorkModeHistory
.EXAMPLE
    work-history
#>
function Get-WorkModeHistory {
    [CmdletBinding()]
    [Alias("work-history")]
    param(
        [Parameter()]
        [int]$Days = 7
    )

    Initialize-WorkModeData

    $timeTrackingPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.TimeTrackingFile
    $data = Get-Content -Path $timeTrackingPath -Raw | ConvertFrom-Json

    if (-not $data.Sessions -or $data.Sessions.Count -eq 0) {
        Write-Host "No sessions found." -ForegroundColor Yellow
        return
    }

    $cutoffDate = (Get-Date).AddDays(-$Days)
    $recentSessions = $data.Sessions | Where-Object {
        [DateTime]$_.StartTime -ge $cutoffDate
    } | Sort-Object -Property StartTime -Descending

    if (-not $recentSessions) {
        Write-Host "No sessions found in the last $Days days." -ForegroundColor Yellow
        return
    }

    Write-Host "=== WorkMode History (Last $Days Days) ===" -ForegroundColor Cyan
    Write-Host ""

    foreach ($session in $recentSessions) {
        $startTime = [DateTime]$session.StartTime
        $modeIcon = if ($session.Mode -eq "Work") { "🔴" } else { "🟢" }
        $modeColor = if ($session.Mode -eq "Work") { "Green" } else { "Yellow" }

        Write-Host "$modeIcon $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor $modeColor -NoNewline
        Write-Host " - $($session.Mode)" -ForegroundColor White -NoNewline
        Write-Host " - $($session.DurationHours.ToString('0.0'))h" -ForegroundColor Cyan
    }
}

#endregion

#region Website Management Functions

<#
.SYNOPSIS
    Enables blocking of distracting websites using hostess.
.DESCRIPTION
    Internal function that uses hostess to enable (turn on) all websites
    in the block list, effectively blocking access to distracting sites.
#>
function Enable-WorkSitesBlocking {
    [CmdletBinding()]
    param()

    Initialize-WorkModeData

    $sitesConfigPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.SitesConfigFile
    $sitesData = Get-Content -Path $sitesConfigPath -Raw | ConvertFrom-Json

    $allSites = $sitesData.BlockSites + $sitesData.CustomSites
    $hostessPath = $script:WorkModeConfig.HostessPath

    if (-not (Test-Path $hostessPath)) {
        throw "Hostess binary not found at: $hostessPath"
    }

    $blockedCount = 0
    foreach ($site in $allSites) {
        try {
            # Check if site exists in hostess first
            $checkResult = & $hostessPath has $site 2>$null
            if ($LASTEXITCODE -eq 0) {
                # Site exists, enable it
                & $hostessPath on $site | Out-Null
                $blockedCount++
            } else {
                # Site doesn't exist, add it
                & $hostessPath add $site $script:WorkModeConfig.BlockIP | Out-Null
                $blockedCount++
            }
        } catch {
            Write-Warning "Failed to block site $site`: $($_.Exception.Message)"
        }
    }

    Write-Host "Blocked $blockedCount distracting websites" -ForegroundColor Green
}

<#
.SYNOPSIS
    Disables blocking of distracting websites using hostess.
.DESCRIPTION
    Internal function that uses hostess to disable (turn off) all websites
    in the block list, allowing access to previously blocked sites.
#>
function Disable-WorkSitesBlocking {
    [CmdletBinding()]
    param()

    Initialize-WorkModeData

    $sitesConfigPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.SitesConfigFile
    $sitesData = Get-Content -Path $sitesConfigPath -Raw | ConvertFrom-Json

    $allSites = $sitesData.BlockSites + $sitesData.CustomSites
    $hostessPath = $script:WorkModeConfig.HostessPath

    if (-not (Test-Path $hostessPath)) {
        throw "Hostess binary not found at: $hostessPath"
    }

    $unblockedCount = 0
    foreach ($site in $allSites) {
        try {
            & $hostessPath off $site | Out-Null
            $unblockedCount++
        } catch {
            # Site might not exist, which is fine
            continue
        }
    }

    Write-Host "Unblocked $unblockedCount websites" -ForegroundColor Green
}

<#
.SYNOPSIS
    Adds a website to the work mode block list.
.DESCRIPTION
    Adds a new website to the custom block list. The site will be
    blocked when WorkMode is enabled.
.PARAMETER Site
    The website domain to add to the block list.
.EXAMPLE
    Add-WorkBlockSite -Site "distractingsite.com"
.EXAMPLE
    add-block-site reddit.com
#>
function Add-WorkBlockSite {
    [CmdletBinding()]
    [Alias("add-block-site")]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Site
    )

    # Clean up the site input
    $site = $site.Trim().ToLower()
    if ($site -notlike "*.*") {
        Write-Error "Invalid website format. Please use format like 'example.com'"
        return
    }

    Initialize-WorkModeData

    $sitesConfigPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.SitesConfigFile
    $sitesData = Get-Content -Path $sitesConfigPath -Raw | ConvertFrom-Json

    if ($site -in $sitesData.BlockSites -or $site -in $sitesData.CustomSites) {
        Write-Host "Site '$site' is already in the block list." -ForegroundColor Yellow
        return
    }

    $sitesData.CustomSites += $site
    $sitesData.LastUpdated = (Get-Date).ToString("o")

    $sitesData | ConvertTo-Json -Depth 10 | Set-Content -Path $sitesConfigPath

    Write-Host "✅ Added '$site' to block list" -ForegroundColor Green
    Write-Host "The site will be blocked when WorkMode is enabled." -ForegroundColor Cyan

    # If currently in work mode, block it immediately
    if ($script:CurrentSession.Mode -eq "Work") {
        try {
            $hostessPath = $script:WorkModeConfig.HostessPath
            if (Test-Path $hostessPath) {
                & $hostessPath add $site $script:WorkModeConfig.BlockIP | Out-Null
                & $hostessPath on $site | Out-Null
                Write-Host "Site blocked immediately (currently in WorkMode)" -ForegroundColor Green
            }
        } catch {
            Write-Warning "Failed to block site immediately: $($_.Exception.Message)"
        }
    }
}

<#
.SYNOPSIS
    Removes a website from the work mode block list.
.DESCRIPTION
    Removes a website from the custom block list. The site will no longer
    be blocked when WorkMode is enabled.
.PARAMETER Site
    The website domain to remove from the block list.
.EXAMPLE
    Remove-WorkBlockSite -Site "distractingsite.com"
.EXAMPLE
    remove-block-site reddit.com
#>
function Remove-WorkBlockSite {
    [CmdletBinding()]
    [Alias("remove-block-site")]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Site
    )

    # Clean up the site input
    $site = $site.Trim().ToLower()

    Initialize-WorkModeData

    $sitesConfigPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.SitesConfigFile
    $sitesData = Get-Content -Path $sitesConfigPath -Raw | ConvertFrom-Json

    if ($site -in $sitesData.BlockSites) {
        Write-Host "Cannot remove '$site' - it's in the default block list." -ForegroundColor Red
        return
    }

    if ($site -notin $sitesData.CustomSites) {
        Write-Host "Site '$site' is not in the custom block list." -ForegroundColor Yellow
        return
    }

    $sitesData.CustomSites = $sitesData.CustomSites | Where-Object { $_ -ne $site }
    $sitesData.LastUpdated = (Get-Date).ToString("o")

    $sitesData | ConvertTo-Json -Depth 10 | Set-Content -Path $sitesConfigPath

    Write-Host "✅ Removed '$site' from block list" -ForegroundColor Green

    # If currently in work mode, unblock it immediately
    if ($script:CurrentSession.Mode -eq "Work") {
        try {
            $hostessPath = $script:WorkModeConfig.HostessPath
            if (Test-Path $hostessPath) {
                & $hostessPath off $site | Out-Null
                Write-Host "Site unblocked immediately (currently in WorkMode)" -ForegroundColor Green
            }
        } catch {
            Write-Warning "Failed to unblock site immediately: $($_.Exception.Message)"
        }
    }
}

<#
.SYNOPSIS
    Shows all websites in the work mode block list.
.DESCRIPTION
    Displays all websites that are currently configured to be blocked
    when WorkMode is enabled, separated into default and custom lists.
.EXAMPLE
    Get-WorkBlockSites
.EXAMPLE
    show-block-sites
#>
function Get-WorkBlockSites {
    [CmdletBinding()]
    [Alias("show-block-sites")]
    param()

    Initialize-WorkModeData

    $sitesConfigPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.SitesConfigFile
    $sitesData = Get-Content -Path $sitesConfigPath -Raw | ConvertFrom-Json

    Write-Host "=== WorkMode Block List ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Default Sites ($($sitesData.BlockSites.Count)):" -ForegroundColor White
    foreach ($site in $sitesData.BlockSites) {
        Write-Host "  • $site" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "Custom Sites ($($sitesData.CustomSites.Count)):" -ForegroundColor White
    foreach ($site in $sitesData.CustomSites) {
        Write-Host "  • $site" -ForegroundColor Magenta
    }

    Write-Host ""
    Write-Host "Total: $($sitesData.BlockSites.Count + $sitesData.CustomSites.Count) sites" -ForegroundColor Cyan
}

#endregion

#region Helper Functions

<#
.SYNOPSIS
    Formats a TimeSpan into a human-readable duration string.
.DESCRIPTION
    Internal function to convert TimeSpan objects into readable
    duration strings (e.g., "2h 15m 30s").
.PARAMETER Duration
    The TimeSpan object to format.
#>
function Format-Duration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [TimeSpan]$Duration
    )

    $parts = @()

    if ($Duration.TotalHours -ge 1) {
        $hours = [Math]::Floor($Duration.TotalHours)
        $parts += "$hours" + "h"
    }

    $minutes = $Duration.Minutes
    if ($minutes -gt 0) {
        $parts += "$minutes" + "m"
    }

    $seconds = $Duration.Seconds
    if ($seconds -gt 0 -and $Duration.TotalHours -lt 1) {
        $parts += "$seconds" + "s"
    }

    if ($parts.Count -eq 0) {
        return "0s"
    }

    return $parts -join " "
}

<#
.SYNOPSIS
    Gets today's work mode statistics.
.DESCRIPTION
    Internal function to calculate today's work and normal time
    statistics from the tracking data.
#>
function Get-TodayStats {
    [CmdletBinding()]
    param()

    $timeTrackingPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.TimeTrackingFile
    $data = Get-Content -Path $timeTrackingPath -Raw | ConvertFrom-Json

    if (-not $data.Sessions) {
        return $null
    }

    $today = Get-Date.ToString("yyyy-MM-dd")
    $todaySessions = $data.Sessions | Where-Object { $_.Date -eq $today }

    if (-not $todaySessions) {
        return @{
            WorkTime = "0h 0m"
            NormalTime = "0h 0m"
            WorkPercentage = 0
        }
    }

    $workMinutes = ($todaySessions | Where-Object { $_.Mode -eq "Work" } | Measure-Object -Property DurationMinutes -Sum).Sum
    $normalMinutes = ($todaySessions | Where-Object { $_.Mode -eq "Normal" } | Measure-Object -Property DurationMinutes -Sum).Sum

    $totalMinutes = $workMinutes + $normalMinutes
    $workPercentage = if ($totalMinutes -gt 0) { [Math]::Round(($workMinutes / $totalMinutes) * 100, 1) } else { 0 }

    return @{
        WorkTime = Format-Duration (New-TimeSpan -Minutes $workMinutes)
        NormalTime = Format-Duration (New-TimeSpan -Minutes $normalMinutes)
        WorkPercentage = $workPercentage
    }
}

<#
.SYNOPSIS
    Updates the PowerShell prompt to show WorkMode status.
.DESCRIPTION
    Internal function to update the prompt to display the current
    WorkMode status with appropriate colors and icons.
#>
function Update-WorkModePrompt {
    [CmdletBinding()]
    param()

    # This function will be called when the module is imported
    # The actual prompt update logic will be handled in the profile
}

#endregion

#region Module Updates and Maintenance

<#
.SYNOPSIS
    Checks for updates to the WorkMode module.
.DESCRIPTION
    Checks GitHub for newer versions of WorkMode and hostess binary.
.EXAMPLE
    Update-WorkMode
.EXAMPLE
    work-update
#>
function Update-WorkMode {
    [CmdletBinding()]
    [Alias("work-update")]
    param(
        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$WhatIf
    )

    Write-Host "🔄 Checking for WorkMode updates..." -ForegroundColor Cyan

    try {
        # Check GitHub for latest hostess release
        $response = Invoke-RestMethod -Uri $script:WorkModeConfig.GitHubApiUrl -ErrorAction Stop
        $latestVersion = $response.tag_name.TrimStart('v')
        $currentHostessVersion = $null

        # Get current hostess version
        try {
            $hostessOutput = & $script:WorkModeConfig.HostessPath --help 2>$null
            if ($hostessOutput -match "hostess") {
                $currentHostessVersion = "installed (version unknown)"
            }
        } catch {
            $currentHostessVersion = "not working"
        }

        Write-Host "Current hostess: $currentHostessVersion" -ForegroundColor White
        Write-Host "Latest hostess: $latestVersion" -ForegroundColor White

        # Find Windows binary
        $asset = $response.assets | Where-Object { $_.name -like "*windows*amd64*.exe" -or $_.name -like "*windows*.exe" } | Select-Object -First 1

        if (-not $asset) {
            Write-Warning "No suitable Windows binary found in release"
            return
        }

        $updateAvailable = $true
        $updateReason = "newer version available"

        if ($Force) {
            $updateReason = "forced update"
        } elseif ($currentHostessVersion -eq "not working") {
            $updateReason = "current binary not working"
        }

        if (-not $updateAvailable -and -not $Force) {
            Write-Host "✅ WorkMode is up to date" -ForegroundColor Green
            return
        }

        Write-Host "📥 Update available ($updateReason)" -ForegroundColor Yellow

        if ($WhatIf) {
            Write-Host "What if: Would download $($asset.name)" -ForegroundColor Cyan
            return
        }

        # Confirm update
        $response = Read-Host "Download and install update? (y/N) [default: N]"
        if ($response -notmatch '^[yY]$') {
            Write-Host "Update cancelled" -ForegroundColor Yellow
            return
        }

        # Download update
        $tempDir = Join-Path $env:TEMP "WorkModeUpdate"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }

        $downloadPath = Join-Path $tempDir $asset.name

        Write-Host "Downloading $($asset.name)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $downloadPath -ErrorAction Stop

        # Backup current binary
        $backupPath = "$($script:WorkModeConfig.HostessPath).backup"
        if (Test-Path $script:WorkModeConfig.HostessPath) {
            Copy-Item -Path $script:WorkModeConfig.HostessPath -Destination $backupPath -Force
            Write-Host "Backed up current binary" -ForegroundColor Green
        }

        # Replace binary
        Copy-Item -Path $downloadPath -Destination $script:WorkModeConfig.HostessPath -Force

        # Test new binary
        try {
            & $script:WorkModeConfig.HostessPath --help | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Update successful!" -ForegroundColor Green
                Write-Host "Hostess updated to version $latestVersion" -ForegroundColor White
            } else {
                throw "New binary not working"
            }
        } catch {
            Write-Warning "Update failed, restoring backup..."
            if (Test-Path $backupPath) {
                Copy-Item -Path $backupPath -Destination $script:WorkModeConfig.HostessPath -Force
                Write-Host "Restored previous version" -ForegroundColor Green
            }
            throw "Update failed: $($_.Exception.Message)"
        }

        # Cleanup
        Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $backupPath -Force -ErrorAction SilentlyContinue

    } catch {
        Write-Error "Update failed: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Tests the WorkMode installation.
.DESCRIPTION
    Verifies that all WorkMode components are working correctly.
.EXAMPLE
    Test-WorkModeInstallation
.EXAMPLE
    work-test
#>
function Test-WorkModeInstallation {
    [CmdletBinding()]
    [Alias("work-test")]
    param()

    Write-Host "🔧 Testing WorkMode installation..." -ForegroundColor Cyan
    Write-Host ""

    $tests = @(
        @{
            Name = "Module Directory"
            Test = { Test-Path $PSScriptRoot }
            Message = "Module directory exists"
            Critical = $true
        },
        @{
            Name = "Hostess Binary"
            Test = { Test-Path $script:WorkModeConfig.HostessPath }
            Message = "Hostess binary exists"
            Critical = $true
        },
        @{
            Name = "Hostess Functionality"
            Test = {
                try {
                    & $script:WorkModeConfig.HostessPath --help | Out-Null
                    $LASTEXITCODE -eq 0
                } catch {
                    $false
                }
            }
            Message = "Hostess binary working"
            Critical = $true
        },
        @{
            Name = "Data Directory"
            Test = { Test-Path $script:WorkModeConfig.DataDir }
            Message = "Data directory accessible"
            Critical = $false
        },
        @{
            Name = "Module Functions"
            Test = { Get-Command Enable-WorkMode -ErrorAction SilentlyContinue }
            Message = "WorkMode functions available"
            Critical = $true
        },
        @{
            Name = "Configuration Files"
            Test = {
                $sitesPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.SitesConfigFile
                Test-Path $sitesPath
            }
            Message = "Configuration files exist"
            Critical = $false
        }
    )

    $passed = 0
    $failed = 0
    $criticalFailures = 0

    foreach ($test in $tests) {
        try {
            $result = & $test.Test
            if ($result) {
                Write-Host "✅ $($test.Message)" -ForegroundColor Green
                $passed++
            } else {
                Write-Host "❌ $($test.Message)" -ForegroundColor Red
                $failed++
                if ($test.Critical) {
                    $criticalFailures++
                }
            }
        } catch {
            Write-Host "❌ $($test.Message): $($_.Exception.Message)" -ForegroundColor Red
            $failed++
            if ($test.Critical) {
                $criticalFailures++
            }
        }
    }

    Write-Host ""
    Write-Host "Test Results: $passed passed, $failed failed" -ForegroundColor White

    if ($criticalFailures -gt 0) {
        Write-Host "🚨 Critical failures detected! WorkMode may not function correctly." -ForegroundColor Red
        Write-Host "Try reinstalling: .\Install-WorkMode.ps1 -Repair" -ForegroundColor Yellow
        return $false
    } elseif ($failed -gt 0) {
        Write-Host "⚠️  Some tests failed, but WorkMode should still work." -ForegroundColor Yellow
        return $true
    } else {
        Write-Host "🎉 All tests passed! WorkMode is properly installed." -ForegroundColor Green
        return $true
    }
}

<#
.SYNOPSIS
    Shows WorkMode module information.
.DESCRIPTION
    Displays version information and installation details.
.EXAMPLE
    Get-WorkModeInfo
.EXAMPLE
    work-info
#>
function Get-WorkModeInfo {
    [CmdletBinding()]
    [Alias("work-info")]
    param()

    Write-Host "📋 WorkMode Module Information" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Module Version: $($script:WorkModeConfig.ModuleVersion)" -ForegroundColor White
    Write-Host "Module Path: $PSScriptRoot" -ForegroundColor White
    Write-Host "Data Directory: $($script:WorkModeConfig.DataDir)" -ForegroundColor White
    Write-Host "Hostess Path: $($script:WorkModeConfig.HostessPath)" -ForegroundColor White
    Write-Host ""

    # Check hostess version
    try {
        $hostessOutput = & $script:WorkModeConfig.HostessPath --help 2>$null
        if ($hostessOutput -match "hostess") {
            Write-Host "Hostess: Installed and working" -ForegroundColor Green
        }
    } catch {
        Write-Host "Hostess: Not working or not found" -ForegroundColor Red
    }

    # Check data directory
    if (Test-Path $script:WorkModeConfig.DataDir) {
        $timeTrackingPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.TimeTrackingFile
        $sitesPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.SitesConfigFile

        Write-Host "Data Directory: Accessible" -ForegroundColor Green

        if (Test-Path $timeTrackingPath) {
            $data = Get-Content $timeTrackingPath -Raw | ConvertFrom-Json
            $sessionCount = if ($data.Sessions) { $data.Sessions.Count } else { 0 }
            Write-Host "Time Tracking: $sessionCount sessions recorded" -ForegroundColor White
        }

        if (Test-Path $sitesPath) {
            $sitesData = Get-Content $sitesPath -Raw | ConvertFrom-Json
            $totalSites = $sitesData.BlockSites.Count + $sitesData.CustomSites.Count
            Write-Host "Block Lists: $totalSites sites configured" -ForegroundColor White
        }
    } else {
        Write-Host "Data Directory: Not found (will be created on first use)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Use 'work-test' to verify installation" -ForegroundColor Cyan
    Write-Host "Use 'work-update' to check for updates" -ForegroundColor Cyan
}

#endregion

#region Module Initialization

# Initialize data directory and configuration when module is imported
Initialize-WorkModeData

# Export functions
Export-ModuleMember -Function @(
    'Enable-WorkMode', 'Disable-WorkMode', 'Get-WorkModeStatus',
    'Get-ProductivityStats', 'Get-WorkModeHistory',
    'Add-WorkBlockSite', 'Remove-WorkBlockSite', 'Get-WorkBlockSites',
    'Update-WorkMode', 'Test-WorkModeInstallation', 'Get-WorkModeInfo'
)

# Export aliases
Export-ModuleMember -Alias @(
    'work-on', 'work-off', 'work-status', 'work-stats', 'work-history',
    'add-block-site', 'remove-block-site', 'show-block-sites',
    'work-update', 'work-test', 'work-info'
)

#endregion