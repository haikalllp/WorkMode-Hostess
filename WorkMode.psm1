###############################################################################
#                                                                             #
#                           WorkMode Module                                   #
#                                                                             #
#         A PowerShell productivity module for time tracking and              #
#         website blocking during work sessions using hostess                 #
#                                                                             #
#                               Version 1.0                                   #
#                                                                             #
###############################################################################

#region Module Variables and Configuration

# Module configuration
$script:WorkModeConfig = @{
    DataDir        = "$env:USERPROFILE\Documents\PowerShell\WorkMode"
    TimeTrackingFile = "time-tracking.json"
    SitesConfigFile  = "work-sites.json"
    HostessPath    = "$PSScriptRoot\hostess.exe"
    BlockIP        = "127.0.0.1"
    WorkHoursStart = 9
    WorkHoursEnd   = 17
    ModuleVersion  = "1.0.0"
    GitHubRepo     = "cbednarski/hostess"
}
# Compute dependent value after hashtable creation (avoids null expansion)
$script:WorkModeConfig.GitHubApiUrl = "https://api.github.com/repos/$($script:WorkModeConfig.GitHubRepo)/releases/latest"

# Current session state
$script:CurrentSession = @{
    Mode      = "Normal"  # Work or Normal
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
    "snapchat.com", "www.snapchat.com",
    "linkedin.com", "www.linkedin.com",
    "pinterest.com", "www.pinterest.com",
    "tumblr.com", "www.tumblr.com",
    "imgur.com", "www.imgur.com",
    "twitch.tv", "www.twitch.tv",
    "discord.com", "www.discord.com",
    "steam.com", "www.steam.com",
    "epicgames.com", "www.epicgames.com"
)

# Initialize data directory
function Initialize-WorkModeData {
    if (-not (Test-Path $script:WorkModeConfig.DataDir)) {
        New-Item -ItemType Directory -Path $script:WorkModeConfig.DataDir -Force | Out-Null
    }

    $timeTrackingPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.TimeTrackingFile
    $sitesConfigPath  = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.SitesConfigFile

    # Initialize time tracking file if it doesn't exist
    if (-not (Test-Path $timeTrackingPath)) {
        @{
            Sessions       = @()
            CurrentSession = $null
            Version        = "1.0"
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $timeTrackingPath -Encoding UTF8
    }

    # Initialize sites configuration if it doesn't exist
    if (-not (Test-Path $sitesConfigPath)) {
        @{
            BlockSites  = $script:DefaultBlockSites
            CustomSites = @()
            Version     = "1.0"
            LastUpdated = (Get-Date).ToString("o")
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $sitesConfigPath -Encoding UTF8
    }
}

#endregion

#region Core WorkMode Functions

function Enable-WorkMode {
    [CmdletBinding()]
    [Alias("wmh-on")]
    param()

    if ($script:CurrentSession.Mode -eq "Work") {
        Write-Host "Already in WorkMode!" -ForegroundColor Yellow
        Get-WorkModeStatus
        return
    }

    Write-Host "🔴 Enabling WorkMode..." -ForegroundColor Red

    try {
        if ($script:CurrentSession.StartTime) {
            Complete-Session -Mode $script:CurrentSession.Mode
        }

        Enable-WorkSitesBlocking

        $script:CurrentSession.Mode = "Work"
        $script:CurrentSession.StartTime = Get-Date
        $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()

        Write-Host "✅ WorkMode enabled - Distractions blocked!" -ForegroundColor Green
        Write-Host "Focus time started at: $($script:CurrentSession.StartTime.ToString('HH:mm:ss'))" -ForegroundColor Cyan

        Update-WorkModePrompt

    } catch {
        Write-Error "Failed to enable WorkMode: $($_.Exception.Message)"
    }
}

function Disable-WorkMode {
    [CmdletBinding()]
    [Alias("wmh-off")]
    param()

    if ($script:CurrentSession.Mode -eq "Normal") {
        Write-Host "Already in NormalMode!" -ForegroundColor Yellow
        Get-WorkModeStatus
        return
    }

    Write-Host "🟢 Disabling WorkMode..." -ForegroundColor Green

    try {
        if ($script:CurrentSession.StartTime) {
            Complete-Session -Mode $script:CurrentSession.Mode
        }

        Disable-WorkSitesBlocking

        $script:CurrentSession.Mode = "Normal"
        $script:CurrentSession.StartTime = Get-Date
        $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()

        Write-Host "✅ NormalMode enabled - Websites accessible!" -ForegroundColor Green
        Write-Host "Break time started at: $($script:CurrentSession.StartTime.ToString('HH:mm:ss'))" -ForegroundColor Cyan

        Update-WorkModePrompt

    } catch {
        Write-Error "Failed to disable WorkMode: $($_.Exception.Message)"
    }
}

function Get-WorkModeStatus {
    [CmdletBinding()]
    [Alias("wmh-status")]
    param()

    Initialize-WorkModeData

    $isWork = $script:CurrentSession.Mode -eq "Work"
    $modeIcon  = if ($isWork) { "🔴" } else { "🟢" }
    $modeColor = if ($isWork) { "Red" } else { "Green" }

    Write-Host "=== WorkMode Status ===" -ForegroundColor Cyan
    Write-Host "Current Mode: $modeIcon $($script:CurrentSession.Mode)" -ForegroundColor $modeColor

    if ($script:CurrentSession.StartTime) {
        $duration   = (Get-Date) - $script:CurrentSession.StartTime
        $durationStr = Format-Duration $duration
        Write-Host "Session Started: $($script:CurrentSession.StartTime.ToString('HH:mm:ss'))" -ForegroundColor White
        Write-Host "Session Duration: $durationStr" -ForegroundColor White
    } else {
        Write-Host "No active session" -ForegroundColor Yellow
    }

    $todayStats = Get-TodayStats
    if ($todayStats) {
        Write-Host "Today's Work Time: $($todayStats.WorkTime)" -ForegroundColor Green
        Write-Host "Today's Normal Time: $($todayStats.NormalTime)" -ForegroundColor Yellow
        Write-Host "Work Percentage: $($todayStats.WorkPercentage)%" -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "Use 'wmh-on' to start focus time or 'wmh-off' for break time" -ForegroundColor White
}

#endregion

#region Time Tracking Functions

function Complete-Session {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Work", "Normal")]
        [string]$Mode
    )

    if (-not $script:CurrentSession.StartTime) { return }

    $endTime  = Get-Date
    $duration = $endTime - $script:CurrentSession.StartTime

    $sessionData = @{
        SessionId      = $script:CurrentSession.SessionId
        Mode           = $Mode
        StartTime      = $script:CurrentSession.StartTime.ToString("o")
        EndTime        = $endTime.ToString("o")
        DurationMinutes= [Math]::Round($duration.TotalMinutes, 2)
        DurationHours  = [Math]::Round($duration.TotalHours, 2)
        Date           = $script:CurrentSession.StartTime.ToString("yyyy-MM-dd")
        DayOfWeek      = $script:CurrentSession.StartTime.DayOfWeek.ToString()
    }

    $timeTrackingPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.TimeTrackingFile
    $data = Get-Content -Path $timeTrackingPath -Raw | ConvertFrom-Json

    $data.Sessions += $sessionData
    $data.CurrentSession = $null

    $data | ConvertTo-Json -Depth 10 | Set-Content -Path $timeTrackingPath -Encoding UTF8

    $script:CurrentSession.StartTime = $null
    $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()
}

function Get-ProductivityStats {
    [CmdletBinding()]
    [Alias("wmh-stats")]
    param()

    Initialize-WorkModeData

    $timeTrackingPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.TimeTrackingFile
    $data = Get-Content -Path $timeTrackingPath -Raw | ConvertFrom-Json

    if (-not $data.Sessions -or $data.Sessions.Count -eq 0) {
        Write-Host "No sessions found. Start tracking with 'wmh-on' or 'wmh-off'" -ForegroundColor Yellow
        return
    }

    Write-Host "=== Productivity Statistics ===" -ForegroundColor Cyan
    Write-Host ""

    $totalSessions  = $data.Sessions.Count
    $workSessions   = $data.Sessions | Where-Object { $_.Mode -eq "Work" }
    $normalSessions = $data.Sessions | Where-Object { $_.Mode -eq "Normal" }

    $totalWorkHours   = ($workSessions   | Measure-Object -Property DurationHours -Sum).Sum
    $totalNormalHours = ($normalSessions | Measure-Object -Property DurationHours -Sum).Sum
    $totalHours       = $totalWorkHours + $totalNormalHours

    $workPercentage = if ($totalHours -gt 0) { [Math]::Round(($totalWorkHours / $totalHours) * 100, 1) } else { 0 }

    Write-Host "📊 Overall Statistics" -ForegroundColor White
    Write-Host "Total Sessions: $totalSessions" -ForegroundColor White
    Write-Host "Total Work Time: $([Math]::Round($totalWorkHours, 1)) hours" -ForegroundColor Green
    Write-Host "Total Normal Time: $([Math]::Round($totalNormalHours, 1)) hours" -ForegroundColor Yellow
    Write-Host "Work Percentage: $workPercentage%" -ForegroundColor Cyan
    Write-Host ""

    $today      = Get-Date
    $todayStr   = $today.ToString("yyyy-MM-dd")
    $todaySess  = $data.Sessions | Where-Object { $_.Date -eq $todayStr }

    if ($todaySess) {
        $todayWorkHours   = ($todaySess | Where-Object { $_.Mode -eq "Work" }   | Measure-Object -Property DurationHours -Sum).Sum
        $todayNormalHours = ($todaySess | Where-Object { $_.Mode -eq "Normal" } | Measure-Object -Property DurationHours -Sum).Sum
        $todayWorkPct = if (($todayWorkHours + $todayNormalHours) -gt 0) {
            [Math]::Round(($todayWorkHours / ($todayWorkHours + $todayNormalHours)) * 100, 1)
        } else { 0 }

        Write-Host "📅 Today's Statistics ($todayStr)" -ForegroundColor White
        Write-Host "Work Time: $([Math]::Round($todayWorkHours, 1)) hours" -ForegroundColor Green
        Write-Host "Normal Time: $([Math]::Round($todayNormalHours, 1)) hours" -ForegroundColor Yellow
        Write-Host "Work Percentage: $todayWorkPct%" -ForegroundColor Cyan
        Write-Host ""
    }

    $weekStart = $today.AddDays(-([int]$today.DayOfWeek))
    $weekSessions = $data.Sessions | Where-Object { [DateTime]$_.Date -ge $weekStart }

    if ($weekSessions) {
        $weekWorkHours   = ($weekSessions | Where-Object { $_.Mode -eq "Work" }   | Measure-Object -Property DurationHours -Sum).Sum
        $weekNormalHours = ($weekSessions | Where-Object { $_.Mode -eq "Normal" } | Measure-Object -Property DurationHours -Sum).Sum
        $weekWorkPct = if (($weekWorkHours + $weekNormalHours) -gt 0) {
            [Math]::Round(($weekWorkHours / ($weekWorkHours + $weekNormalHours)) * 100, 1)
        } else { 0 }

        Write-Host "📆 This Week's Statistics" -ForegroundColor White
        Write-Host "Work Time: $([Math]::Round($weekWorkHours, 1)) hours" -ForegroundColor Green
        Write-Host "Normal Time: $([Math]::Round($weekNormalHours, 1)) hours" -ForegroundColor Yellow
        Write-Host "Work Percentage: $weekWorkPct%" -ForegroundColor Cyan
        Write-Host ""
    }

    if ($script:CurrentSession.StartTime) {
        $currentDuration   = (Get-Date) - $script:CurrentSession.StartTime
        $currentDurationStr = Format-Duration $currentDuration
        Write-Host "⏱️  Current Session" -ForegroundColor White
        Write-Host "Mode: $($script:CurrentSession.Mode)" -ForegroundColor $(if ($script:CurrentSession.Mode -eq "Work") { "Green" } else { "Yellow" })
        Write-Host "Duration: $currentDurationStr" -ForegroundColor White
    }

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

function Get-WorkModeHistory {
    [CmdletBinding()]
    [Alias("wmh-history")]
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
        $isWork = $session.Mode -eq "Work"
        $modeIcon  = if ($isWork) { "🔴" } else { "🟢" }
        $modeColor = if ($isWork) { "Green" } else { "Yellow" }

        Write-Host "$modeIcon $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor $modeColor -NoNewline
        Write-Host " - $($session.Mode)" -ForegroundColor White -NoNewline
        Write-Host " - $($session.DurationHours.ToString('0.0'))h" -ForegroundColor Cyan
    }
}

#endregion

#region Website Management Functions

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
            $checkResult = & $hostessPath has $site 2>$null
            if ($LASTEXITCODE -eq 0) {
                & $hostessPath on $site | Out-Null
                $blockedCount++
            } else {
                & $hostessPath add $site $script:WorkModeConfig.BlockIP | Out-Null
                $blockedCount++
            }
        } catch {
            Write-Warning "Failed to block site $($site): $($_.Exception.Message)"
        }
    }

    Write-Host "Blocked $blockedCount distracting websites" -ForegroundColor Green
}

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
            continue
        }
    }

    Write-Host "Unblocked $unblockedCount websites" -ForegroundColor Green
}

function Add-WorkBlockSite {
    [CmdletBinding()]
    [Alias("wmh-add")]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Site
    )

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

    $sitesData | ConvertTo-Json -Depth 10 | Set-Content -Path $sitesConfigPath -Encoding UTF8

    Write-Host "✅ Added '$site' to block list" -ForegroundColor Green
    Write-Host "The site will be blocked when WorkMode is enabled." -ForegroundColor Cyan

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

function Remove-WorkBlockSite {
    [CmdletBinding()]
    [Alias("wmh-remove")]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Site
    )

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

    $sitesData | ConvertTo-Json -Depth 10 | Set-Content -Path $sitesConfigPath -Encoding UTF8

    Write-Host "✅ Removed '$site' from block list" -ForegroundColor Green

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

function Get-WorkBlockSites {
    [CmdletBinding()]
    [Alias("wmh-list")]
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
    if ($minutes -gt 0) { $parts += "$minutes" + "m" }

    $seconds = $Duration.Seconds
    if ($seconds -gt 0 -and $Duration.TotalHours -lt 1) { $parts += "$seconds" + "s" }

    if ($parts.Count -eq 0) { return "0s" }

    return $parts -join " "
}

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

    $workMinutes   = ($todaySessions | Where-Object { $_.Mode -eq "Work" }   | Measure-Object -Property DurationMinutes -Sum).Sum
    $normalMinutes = ($todaySessions | Where-Object { $_.Mode -eq "Normal" } | Measure-Object -Property DurationMinutes -Sum).Sum

    $totalMinutes = $workMinutes + $normalMinutes
    $workPercentage = if ($totalMinutes -gt 0) { [Math]::Round(($workMinutes / $totalMinutes) * 100, 1) } else { 0 }

    return @{
        WorkTime       = Format-Duration (New-TimeSpan -Minutes $workMinutes)
        NormalTime     = Format-Duration (New-TimeSpan -Minutes $normalMinutes)
        WorkPercentage = $workPercentage
    }
}

function Update-WorkModePrompt {
    [CmdletBinding()]
    param()
    # hook point for profile prompt customization
}

#endregion

#region Module Updates and Maintenance

function Update-WorkMode {
    [CmdletBinding()]
    [Alias("wmh-update")]
    param(
        [Parameter()] [switch]$Force,
        [Parameter()] [switch]$WhatIf
    )

    Write-Host "🔎 Checking for WorkMode updates..." -ForegroundColor Cyan

    try {
        $response = Invoke-RestMethod -Uri $script:WorkModeConfig.GitHubApiUrl -ErrorAction Stop
        $latestVersion = $response.tag_name.TrimStart('v')
        $currentHostessVersion = $null

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

        $asset = $response.assets | Where-Object { $_.name -like "*windows*amd64*.exe" -or $_.name -like "*windows*.exe" } | Select-Object -First 1
        if (-not $asset) { Write-Warning "No suitable Windows binary found in release"; return }

        $updateAvailable = $true
        $updateReason = if ($Force) { "forced update" } elseif ($currentHostessVersion -eq "not working") { "current binary not working" } else { "newer version available" }

        if (-not $updateAvailable -and -not $Force) {
            Write-Host "✅ WorkMode is up to date" -ForegroundColor Green
            return
        }

        Write-Host "📥 Update available ($updateReason)" -ForegroundColor Yellow

        if ($WhatIf) { Write-Host "What if: Would download $($asset.name)" -ForegroundColor Cyan; return }

        $response = Read-Host "Download and install update? (y/N) [default: N]"
        if ($response -notmatch '^[yY]$') { Write-Host "Update cancelled" -ForegroundColor Yellow; return }

        $tempDir = Join-Path $env:TEMP "WorkModeUpdate"
        if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
        $downloadPath = Join-Path $tempDir $asset.name

        Write-Host "Downloading $($asset.name)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $downloadPath -ErrorAction Stop

        $backupPath = "$($script:WorkModeConfig.HostessPath).backup"
        if (Test-Path $script:WorkModeConfig.HostessPath) {
            Copy-Item -Path $script:WorkModeConfig.HostessPath -Destination $backupPath -Force
            Write-Host "Backed up current binary" -ForegroundColor Green
        }

        Copy-Item -Path $downloadPath -Destination $script:WorkModeConfig.HostessPath -Force

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

        Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $backupPath   -Force -ErrorAction SilentlyContinue

    } catch {
        Write-Error "Update failed: $($_.Exception.Message)"
    }
}

function Test-WorkModeInstallation {
    [CmdletBinding()]
    [Alias("wmh-test")]
    param()

    Write-Host "🔧 Testing WorkMode installation..." -ForegroundColor Cyan
    Write-Host ""

    $tests = @(
        @{ Name="Module Directory";     Test={ Test-Path $PSScriptRoot };                           Message="Module directory exists";             Critical=$true  },
        @{ Name="Hostess Binary";       Test={ Test-Path $script:WorkModeConfig.HostessPath };      Message="Hostess binary exists";               Critical=$true  },
        @{ Name="Hostess Functionality";Test={ try { & $script:WorkModeConfig.HostessPath --help | Out-Null; $LASTEXITCODE -eq 0 } catch { $false } };
                                          Message="Hostess binary working";                         Critical=$true  },
        @{ Name="Data Directory";       Test={ Test-Path $script:WorkModeConfig.DataDir };          Message="Data directory accessible";           Critical=$false },
        @{ Name="Module Functions";     Test={ Get-Command Enable-WorkMode -ErrorAction SilentlyContinue };
                                          Message="WorkMode functions available";                    Critical=$true  },
        @{ Name="Configuration Files";  Test={ $sitesPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.SitesConfigFile; Test-Path $sitesPath };
                                          Message="Configuration files exist";                       Critical=$false }
    )

    $passed = 0; $failed = 0; $criticalFailures = 0

    foreach ($test in $tests) {
        try {
            $result = & $test.Test
            if ($result) {
                Write-Host "✅ $($test.Message)" -ForegroundColor Green
                $passed++
            } else {
                Write-Host "❌ $($test.Message)" -ForegroundColor Red
                $failed++
                if ($test.Critical) { $criticalFailures++ }
            }
        } catch {
            Write-Host "❌ $($test.Message): $($_.Exception.Message)" -ForegroundColor Red
            $failed++; if ($test.Critical) { $criticalFailures++ }
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

function Get-WorkModeInfo {
    [CmdletBinding()]
    [Alias("wmh-info")]
    param()

    Write-Host "📚 WorkMode Module Information" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Module Version: $($script:WorkModeConfig.ModuleVersion)" -ForegroundColor White
    Write-Host "Module Path: $PSScriptRoot" -ForegroundColor White
    Write-Host "Data Directory: $($script:WorkModeConfig.DataDir)" -ForegroundColor White
    Write-Host "Hostess Path: $($script:WorkModeConfig.HostessPath)" -ForegroundColor White
    Write-Host ""

    try {
        $hostessOutput = & $script:WorkModeConfig.HostessPath --help 2>$null
        if ($hostessOutput -match "hostess") {
            Write-Host "Hostess: Installed and working" -ForegroundColor Green
        }
    } catch {
        Write-Host "Hostess: Not working or not found" -ForegroundColor Red
    }

    if (Test-Path $script:WorkModeConfig.DataDir) {
        $timeTrackingPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.TimeTrackingFile
        $sitesPath        = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.SitesConfigFile

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
    Write-Host "Use 'wmh-test' to verify installation" -ForegroundColor Cyan
    Write-Host "Use 'wmh-update' to check for updates" -ForegroundColor Cyan
}

#endregion

#region Uninstall and Help Functions

function Uninstall-WorkMode {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="High")]
    [Alias("wmh-uninstall")]
    param(
        [Parameter()] [switch]$Backup,
        [Parameter()] [switch]$KeepData,
        [Parameter()] [switch]$Force
    )

    $modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\WorkMode"
    $dataPath   = "$env:USERPROFILE\Documents\PowerShell\WorkMode"

    Write-Host "🗑️  WorkMode Uninstaller" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Items to be removed:" -ForegroundColor Yellow
    Write-Host "  Module Directory: $modulePath" -ForegroundColor White

    if (-not $KeepData -and (Test-Path $dataPath)) {
        Write-Host "  Data Directory: $dataPath" -ForegroundColor White
        Write-Host "    (includes time-tracking.json and work-sites.json)" -ForegroundColor Gray
    }

    if ($KeepData) {
        Write-Host "  Data Directory: $dataPath (will be preserved)" -ForegroundColor Green
    }

    Write-Host ""

    if (-not $Force -and -not $WhatIfPreference) {
        $response = Read-Host "Continue with uninstallation? (y/N)"
        if ($response -notmatch '^[yY]$') {
            Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
            return
        }
    }

    try {
        if ($Backup -and (Test-Path $dataPath)) {
            $backupPath = "$dataPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $dataPath -Destination $backupPath -Recurse -Force
            Write-Host "✅ Data backed up to: $backupPath" -ForegroundColor Green
        }

        if (Test-Path $modulePath) {
            if ($PSCmdlet.ShouldProcess($modulePath, "Remove module directory")) {
                Remove-Item -Path $modulePath -Recurse -Force
                Write-Host "✅ Module directory removed" -ForegroundColor Green
            }
        } else {
            Write-Host "⚠️  Module directory not found: $modulePath" -ForegroundColor Yellow
        }

        if (-not $KeepData -and (Test-Path $dataPath)) {
            if ($PSCmdlet.ShouldProcess($dataPath, "Remove data directory")) {
                Remove-Item -Path $dataPath -Recurse -Force
                Write-Host "✅ Data directory removed" -ForegroundColor Green
            }
        }

        Write-Host ""
        Write-Host "🎉 WorkMode has been successfully uninstalled!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Note: You may want to remove WorkMode integration from your PowerShell profile:" -ForegroundColor Yellow
        Write-Host "  notepad `$PROFILE" -ForegroundColor White

    } catch {
        Write-Host "❌ Uninstallation failed: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Get-WorkModeHelp {
    [CmdletBinding()]
    [Alias("wmh-help")]
    param(
        [Parameter()] [string]$Command,
        [Parameter()] [ValidateSet("Core", "Sites", "Stats", "System")] [string]$Category,
        [Parameter()] [string]$Search
    )

    $commands = @{
        "wmh-on" = @{
            Description = "Enable WorkMode (block sites, start work timer)"
            Function    = "Enable-WorkMode"
            Category    = "Core"
            Examples    = @("wmh-on", "wmh-on -Verbose")
        }
        "wmh-off" = @{
            Description = "Disable WorkMode (unblock sites, start break timer)"
            Function    = "Disable-WorkMode"
            Category    = "Core"
            Examples    = @("wmh-off", "wmh-off -Verbose")
        }
        "wmh-status" = @{
            Description = "Show current mode and session information"
            Function    = "Get-WorkModeStatus"
            Category    = "Core"
            Examples    = @("wmh-status", "wmh-status -Detailed")
        }
        "wmh-stats" = @{
            Description = "Show comprehensive productivity statistics"
            Function    = "Get-ProductivityStats"
            Category    = "Stats"
            Examples    = @("wmh-stats", "wmh-stats -Today")
        }
        "wmh-history" = @{
            Description = "Display recent session history"
            Function    = "Get-WorkModeHistory"
            Category    = "Stats"
            Examples    = @("wmh-history", "wmh-history -Days 7")
        }
        "wmh-add" = @{
            Description = "Add website to block list"
            Function    = "Add-WorkBlockSite"
            Category    = "Sites"
            Examples    = @("wmh-add reddit.com", "wmh-add tiktok.com -Force")
        }
        "wmh-remove" = @{
            Description = "Remove website from block list"
            Function    = "Remove-WorkBlockSite"
            Category    = "Sites"
            Examples    = @("wmh-remove reddit.com", "wmh-remove linkedin.com")
        }
        "wmh-list" = @{
            Description = "List all blocked websites"
            Function    = "Get-WorkBlockSites"
            Category    = "Sites"
            Examples    = @("wmh-list", "wmh-list -Category Social")
        }
        "wmh-update" = @{
            Description = "Update hostess binary from GitHub releases"
            Function    = "Update-WorkMode"
            Category    = "System"
            Examples    = @("wmh-update", "wmh-update -Force")
        }
        "wmh-test" = @{
            Description = "Test WorkMode installation and dependencies"
            Function    = "Test-WorkModeInstallation"
            Category    = "System"
            Examples    = @("wmh-test", "wmh-test -Detailed")
        }
        "wmh-info" = @{
            Description = "Display WorkMode module information"
            Function    = "Get-WorkModeInfo"
            Category    = "System"
            Examples    = @("wmh-info")
        }
        "wmh-uninstall" = @{
            Description = "Uninstall WorkMode module and files"
            Function    = "Uninstall-WorkMode"
            Category    = "System"
            Examples    = @("wmh-uninstall", "wmh-uninstall -Backup")
        }
        "wmh-help" = @{
            Description = "Show this help information"
            Function    = "Get-WorkModeHelp"
            Category    = "System"
            Examples    = @("wmh-help", "wmh-help -Command wmh-on")
        }
    }

    Write-Host "📖 WorkMode Command Help" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host ""

    if ($Command) {
        if ($commands.ContainsKey($Command)) {
            $cmd = $commands[$Command]
            Write-Host "Command: $Command" -ForegroundColor Yellow
            Write-Host "Description: $($cmd.Description)" -ForegroundColor White
            Write-Host "Category: $($cmd.Category)" -ForegroundColor White
            Write-Host ""
            Write-Host "Examples:" -ForegroundColor Cyan
            foreach ($example in $cmd.Examples) {
                Write-Host "  $example" -ForegroundColor White
            }
            Write-Host ""
            try { Get-Help $cmd.Function -Detailed | Out-Host } catch { Write-Host "Use 'Get-Help $($cmd.Function)' for detailed help." -ForegroundColor Gray }
        } else {
            Write-Host "Command '$Command' not found." -ForegroundColor Red
            Write-Host "Use 'wmh-help' to see all available commands." -ForegroundColor Yellow
        }
        return
    }

    $filtered = $commands
    if ($Category) {
        $filtered = @{}
        foreach ($kv in $commands.GetEnumerator()) {
            if ($kv.Value.Category -eq $Category) { $filtered[$kv.Key] = $kv.Value }
        }
    }
    if ($Search) {
        $filtered = @{}
        foreach ($kv in $commands.GetEnumerator()) {
            if ($kv.Key -like "*$Search*" -or $kv.Value.Description -like "*$Search*") { $filtered[$kv.Key] = $kv.Value }
        }
    }

    if ($filtered.Count -eq 0) { Write-Host "No commands found matching your criteria." -ForegroundColor Yellow; return }

    $categories = @{}
    foreach ($kv in $filtered.GetEnumerator()) {
        $cat = $kv.Value.Category
        if (-not $categories.ContainsKey($cat)) { $categories[$cat] = @{} }
        $categories[$cat][$kv.Key] = $kv.Value
    }

    foreach ($cat in @("Core", "Sites", "Stats", "System")) {
        if ($categories.ContainsKey($cat)) {
            $catIcon = switch ($cat) {
                "Core"   { "🎯" }
                "Sites" { "🌐" }
                "Stats" { "📊" }
                "System" { "⚙️" }
            }
            Write-Host "$catIcon $cat Commands" -ForegroundColor Yellow
            Write-Host "$('-' * ($cat.Length + 10))" -ForegroundColor Gray

            # Commands in this category
            foreach ($cmdName in $catCommands.Keys | Sort-Object) {
                $cmdInfo = $catCommands[$cmdName]
                Write-Host "  $cmdName" -ForegroundColor Green
                Write-Host "    $($cmdInfo.Description)" -ForegroundColor White
            }
            Write-Host ""
        }
    }

    # Usage tips
    Write-Host "💡 Tips:" -ForegroundColor Cyan
    Write-Host "  • Use 'wmh-help -Command <name>' for detailed help" -ForegroundColor White
    Write-Host "  • Use 'wmh-help -Category <name>' to see command groups" -ForegroundColor White
    Write-Host "  • Use 'wmh-help -Search <text>' to find specific commands" -ForegroundColor White
    Write-Host ""

    # Quick start examples
    Write-Host "🚀 Quick Start:" -ForegroundColor Cyan
    Write-Host "  wmh-on           # Start focusing" -ForegroundColor White
    Write-Host "  wmh-add site.com # Block distracting site" -ForegroundColor White
    Write-Host "  wmh-stats        # View productivity" -ForegroundColor White
    Write-Host "  wmh-off          # Take a break" -ForegroundColor White
    Write-Host "  wmh-help         # Show this help" -ForegroundColor White
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
    'Update-WorkMode', 'Test-WorkModeInstallation', 'Get-WorkModeInfo',
    'Uninstall-WorkMode', 'Get-WorkModeHelp'
)

# Export aliases
Export-ModuleMember -Alias @(
    'wmh-on', 'wmh-off', 'wmh-status', 'wmh-stats', 'wmh-history',
    'wmh-add', 'wmh-remove', 'wmh-list',
    'wmh-update', 'wmh-test', 'wmh-info', 'wmh-help', 'wmh-uninstall'
)

#endregion