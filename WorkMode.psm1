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
            AllSites = $script:DefaultBlockSites
            Categories = @{
                SocialMedia = @(
                    "facebook.com", "www.facebook.com", "fb.com",
                    "twitter.com", "www.twitter.com", "x.com",
                    "instagram.com", "www.instagram.com",
                    "tiktok.com", "www.tiktok.com",
                    "snapchat.com", "www.snapchat.com",
                    "linkedin.com", "www.linkedin.com",
                    "pinterest.com", "www.pinterest.com",
                    "tumblr.com", "www.tumblr.com"
                )
                Entertainment = @(
                    "youtube.com", "www.youtube.com", "youtu.be",
                    "netflix.com", "www.netflix.com",
                    "twitch.tv", "www.twitch.tv",
                    "imgur.com", "www.imgur.com"
                )
                Gaming = @(
                    "steam.com", "www.steam.com",
                    "epicgames.com", "www.epicgames.com",
                    "discord.com", "www.discord.com"
                )
                Forums = @(
                    "reddit.com", "www.reddit.com", "old.reddit.com"
                )
                Custom = @()  # User-added sites
            }
            DistractingApps = @{
                ProcessNames = @("discord", "steam", "EpicGamesLauncher")
                ForceClose = $false
                WarningMessage = "Closing distracting apps to improve focus..."
            }
            ForceCloseApps = $false
            Version = "2.0"
            LastUpdated = (Get-Date).ToString("o")
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $sitesConfigPath -Encoding UTF8
    } else {
        # Check if migration is needed
        try {
            $sitesData = Get-Content -Path $sitesConfigPath -Raw | ConvertFrom-Json
            
            # If this is the old format (no AllSites property), migrate to new format
            if (-not $sitesData.AllSites) {
                Write-Host "🔄 Detected old configuration format. Migrating to new unified format..." -ForegroundColor Yellow
                
                # Perform migration
                $migrationSuccess = Migrate-WorkModeConfiguration -SitesConfigPath $sitesConfigPath -SitesData $sitesData
                
                if ($migrationSuccess) {
                    Write-Host "✅ Configuration migrated successfully to new unified format." -ForegroundColor Green
                } else {
                    Write-Warning "Configuration migration failed. Please check your configuration manually."
                }
            }
        } catch {
            Write-Warning "Failed to check configuration format: $($_.Exception.Message)"
        }
    }
}

function Migrate-WorkModeConfiguration {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SitesConfigPath,
        
        [Parameter(Mandatory=$true)]
        [object]$SitesData
    )
    
    try {
        # Create backup of existing configuration
        $backupPath = "$SitesConfigPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $SitesConfigPath -Destination $backupPath -Force
        Write-Debug "Created backup at: $backupPath"
        
        # Create new unified structure
        $newConfig = @{
            AllSites = @()
            Categories = @{
                SocialMedia = @(
                    "facebook.com", "www.facebook.com", "fb.com",
                    "twitter.com", "www.twitter.com", "x.com",
                    "instagram.com", "www.instagram.com",
                    "tiktok.com", "www.tiktok.com",
                    "snapchat.com", "www.snapchat.com",
                    "linkedin.com", "www.linkedin.com",
                    "pinterest.com", "www.pinterest.com",
                    "tumblr.com", "www.tumblr.com"
                )
                Entertainment = @(
                    "youtube.com", "www.youtube.com", "youtu.be",
                    "netflix.com", "www.netflix.com",
                    "twitch.tv", "www.twitch.tv",
                    "imgur.com", "www.imgur.com"
                )
                Gaming = @(
                    "steam.com", "www.steam.com",
                    "epicgames.com", "www.epicgames.com",
                    "discord.com", "www.discord.com"
                )
                Forums = @(
                    "reddit.com", "www.reddit.com", "old.reddit.com"
                )
                Custom = @()  # User-added sites
            }
            DistractingApps = @{
                ProcessNames = @("discord", "steam", "EpicGamesLauncher")
                ForceClose = $false
                WarningMessage = "Closing distracting apps to improve focus..."
            }
            ForceCloseApps = if ($SitesData.ForceCloseApps -ne $null) { $SitesData.ForceCloseApps } else { $false }
            Version = "2.0"
            LastUpdated = (Get-Date).ToString("o")
            MigrationInfo = @{
                MigratedFrom = $SitesData.Version
                MigrationDate = (Get-Date).ToString("o")
                BackupPath = $backupPath
            }
        }
        
        # Add default sites to AllSites
        $newConfig.AllSites = $script:DefaultBlockSites
        
        # Add user's custom sites to AllSites and Custom category
        if ($SitesData.CustomSites -and $SitesData.CustomSites.Count -gt 0) {
            foreach ($site in $SitesData.CustomSites) {
                # Only add if not already in default list
                if ($site -notin $newConfig.AllSites) {
                    $newConfig.AllSites += $site
                    $newConfig.Categories.Custom += $site
                }
            }
        }
        
        # Write new configuration
        $newConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $SitesConfigPath -Encoding UTF8
        
        return $true
    } catch {
        Write-Error "Migration failed: $($_.Exception.Message)"
        
        # Try to restore from backup if migration failed
        if ($backupPath -and (Test-Path $backupPath)) {
            try {
                Copy-Item -Path $backupPath -Destination $SitesConfigPath -Force
                Write-Host "Restored original configuration from backup." -ForegroundColor Yellow
            } catch {
                Write-Error "Failed to restore backup: $($_.Exception.Message)"
            }
        }
        
        return $false
    }
}

#endregion

#region Core WorkMode Functions

function Enable-WorkMode {
    [CmdletBinding()]
    [Alias("wmh-on")]
    param(
        [switch]$Force
    )

    Assert-Admin

    if ($script:CurrentSession.Mode -eq "Work" -and -not $Force) {
        Write-Host "Already in WorkMode!" -ForegroundColor Yellow
        Get-WorkModeStatus
        return
    }

    if ($Force) {
        Write-Host "🔴 Force enabling WorkMode..." -ForegroundColor Red
        Write-Host "⚠️  Bypassing state checks and forcing mode transition" -ForegroundColor Yellow
    } else {
        Write-Host "🔴 Enabling WorkMode..." -ForegroundColor Red
    }

    try {
        # Force complete any existing session regardless of current mode
        if ($script:CurrentSession.StartTime) {
            try {
                Complete-Session -Mode $script:CurrentSession.Mode
            } catch {
                if ($Force) {
                    Write-Warning "Could not complete existing session normally, forcing transition..."
                    # Reset session state if corrupted
                    $script:CurrentSession.StartTime = $null
                    $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()
                } else {
                    throw
                }
            }
        }

        # Check for running browsers before blocking sites
        $runningBrowsers = Get-RunningBrowserProcesses
        if ($runningBrowsers) {
            $config = Get-WorkModeConfiguration
            $choice = Show-BrowserCloseConfirmation -Processes $runningBrowsers

            switch ($choice) {
                'graceful' {
                    $success = Close-BrowsersGracefully -Processes $runningBrowsers -ForceClose $config.ForceCloseApps
                    if (-not $success) {
                        Write-Warning "Some browsers could not be closed. Site blocking may not work properly."
                        $continue = Read-Host "Continue anyway? (y/N)"
                        if ($continue -notmatch '^[yY]$') {
                            Write-Host "WorkMode enable cancelled." -ForegroundColor Yellow
                            return
                        }
                    }
                }
                'skip' {
                    Write-Host "Skipping browser close. Site blocking may not work properly." -ForegroundColor Yellow
                }
                'cancel' {
                    Write-Host "WorkMode enable cancelled." -ForegroundColor Yellow
                    return
                }
            }
        }

        # Check for running distracting apps before blocking sites
        $runningDistractingApps = Get-RunningDistractingApps
        if ($runningDistractingApps) {
            $config = Get-WorkModeConfiguration
            $appNames = $runningDistractingApps | Select-Object -ExpandProperty ProcessName -Unique | Sort-Object
            $appList = $appNames -join ', '

            Write-Host "⚠️  Distracting applications detected:" -ForegroundColor Yellow
            Write-Host "   $appList" -ForegroundColor White
            Write-Host ""
            Write-Host $config.DistractingApps.WarningMessage -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Choose an option:" -ForegroundColor White
            Write-Host "  1. Attempt to close apps gracefully (recommended)" -ForegroundColor Green
            Write-Host "  2. Skip and continue (may cause issues)" -ForegroundColor Yellow
            Write-Host "  3. Cancel operation" -ForegroundColor Red
            Write-Host ""

            $response = Read-Host "Enter your choice (1/2/3)"

            switch ($response) {
                '1' {
                    $success = Close-DistractingApps -Processes $runningDistractingApps -ForceClose $config.DistractingApps.ForceClose
                    if (-not $success) {
                        Write-Warning "Some distracting apps could not be closed."
                        $continue = Read-Host "Continue anyway? (y/N)"
                        if ($continue -notmatch '^[yY]$') {
                            Write-Host "WorkMode enable cancelled." -ForegroundColor Yellow
                            return
                        }
                    }
                }
                '2' {
                    Write-Host "Skipping distracting app close. These apps may still distract you." -ForegroundColor Yellow
                }
                '3' {
                    Write-Host "WorkMode enable cancelled." -ForegroundColor Yellow
                    return
                }
                default {
                    Write-Host "Invalid choice. Please select 1, 2, or 3." -ForegroundColor Red
                    # Re-prompt by continuing the loop
                    continue
                }
            }
        }

        Enable-WorkSitesBlocking

        $script:CurrentSession.Mode = "Work"
        $script:CurrentSession.StartTime = Get-Date
        $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()

        Save-CurrentSession

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
    param(
        [switch]$Force
    )

    Assert-Admin

    if ($script:CurrentSession.Mode -eq "Normal" -and -not $Force) {
        Write-Host "Already in NormalMode!" -ForegroundColor Yellow
        Get-WorkModeStatus
        return
    }

    if ($Force) {
        Write-Host "🟢 Force disabling WorkMode..." -ForegroundColor Green
        Write-Host "⚠️  Bypassing state checks and forcing mode transition" -ForegroundColor Yellow
    } else {
        Write-Host "🟢 Disabling WorkMode..." -ForegroundColor Green
    }

    try {
        # Force complete any existing session regardless of current mode
        if ($script:CurrentSession.StartTime) {
            try {
                Complete-Session -Mode $script:CurrentSession.Mode
            } catch {
                if ($Force) {
                    Write-Warning "Could not complete existing session normally, forcing transition..."
                    # Reset session state if corrupted
                    $script:CurrentSession.StartTime = $null
                    $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()
                } else {
                    throw
                }
            }
        }

        Disable-WorkSitesBlocking

        $script:CurrentSession.Mode = "Normal"
        $script:CurrentSession.StartTime = Get-Date
        $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()

        Save-CurrentSession

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
        $durationStr = Format-Duration -Duration $duration
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

    if (-not $script:CurrentSession.StartTime) {
        Write-Debug "Complete-Session: No active session to complete"
        return
    }

    try {
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

        # Ensure data file exists
        if (-not (Test-Path $timeTrackingPath)) {
            Initialize-WorkModeData
        }

        $data = Get-Content -Path $timeTrackingPath -Raw | ConvertFrom-Json

        # Ensure Sessions array exists
        if (-not $data.Sessions) {
            $data.Sessions = @()
        }

        $data.Sessions += $sessionData
        $data.CurrentSession = $null

        # Atomic write with backup
        $backupPath = "$timeTrackingPath.bak"
        if (Test-Path $timeTrackingPath) {
            Copy-Item -Path $timeTrackingPath -Destination $backupPath -Force
        }

        $data | ConvertTo-Json -Depth 10 | Set-Content -Path $timeTrackingPath -Encoding UTF8

        # Remove backup on successful write
        if (Test-Path $backupPath) {
            Remove-Item -Path $backupPath -Force
        }

        Write-Debug "Complete-Session: Session saved successfully - Mode: $Mode, Duration: $($sessionData.DurationMinutes) minutes"

        $script:CurrentSession.StartTime = $null
        $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()

    } catch {
        Write-Error "Failed to complete session: $($_.Exception.Message)"
        # Restore from backup if available
        $backupPath = "$timeTrackingPath.bak"
        if (Test-Path $backupPath) {
            try {
                Copy-Item -Path $backupPath -Destination $timeTrackingPath -Force
                Write-Warning "Restored data from backup after save failure"
            } catch {
                Write-Error "Failed to restore backup: $($_.Exception.Message)"
            }
        }
        throw
    }
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

    $totalWorkMinutes   = ($workSessions   | Measure-Object -Property DurationMinutes -Sum).Sum
    $totalNormalMinutes = ($normalSessions | Measure-Object -Property DurationMinutes -Sum).Sum
    $totalMinutes       = $totalWorkMinutes + $totalNormalMinutes

    $workPercentage = if ($totalMinutes -gt 0) { [Math]::Round(($totalWorkMinutes / $totalMinutes) * 100, 1) } else { 0 }

    Write-Host "📊 Overall Statistics" -ForegroundColor White
    Write-Host "Total Sessions: $totalSessions" -ForegroundColor White
    Write-Host "Total Work Time: $(Format-Duration -Duration (New-TimeSpan -Minutes $totalWorkMinutes))" -ForegroundColor Green
    Write-Host "Total Normal Time: $(Format-Duration -Duration (New-TimeSpan -Minutes $totalNormalMinutes))" -ForegroundColor Yellow
    Write-Host "Work Percentage: $workPercentage%" -ForegroundColor Cyan
    Write-Host ""

    $today      = Get-Date
    $todayStr   = $today.ToString("yyyy-MM-dd")
    $todaySess  = $data.Sessions | Where-Object { $_.Date -eq $todayStr }

    if ($todaySess) {
        $todayWorkMinutes   = ($todaySess | Where-Object { $_.Mode -eq "Work" }   | Measure-Object -Property DurationMinutes -Sum).Sum
        $todayNormalMinutes = ($todaySess | Where-Object { $_.Mode -eq "Normal" } | Measure-Object -Property DurationMinutes -Sum).Sum
        $todayWorkPct = if (($todayWorkMinutes + $todayNormalMinutes) -gt 0) {
            [Math]::Round(($todayWorkMinutes / ($todayWorkMinutes + $todayNormalMinutes)) * 100, 1)
        } else { 0 }

        Write-Host "📅 Today's Statistics ($todayStr)" -ForegroundColor White
        Write-Host "Work Time: $(Format-Duration -Duration (New-TimeSpan -Minutes $todayWorkMinutes))" -ForegroundColor Green
        Write-Host "Normal Time: $(Format-Duration -Duration (New-TimeSpan -Minutes $todayNormalMinutes))" -ForegroundColor Yellow
        Write-Host "Work Percentage: $todayWorkPct%" -ForegroundColor Cyan
        Write-Host ""
    }

    $weekStart = $today.AddDays(-([int]$today.DayOfWeek))
    $weekSessions = $data.Sessions | Where-Object { [DateTime]$_.Date -ge $weekStart }

    if ($weekSessions) {
        $weekWorkMinutes   = ($weekSessions | Where-Object { $_.Mode -eq "Work" }   | Measure-Object -Property DurationMinutes -Sum).Sum
        $weekNormalMinutes = ($weekSessions | Where-Object { $_.Mode -eq "Normal" } | Measure-Object -Property DurationMinutes -Sum).Sum
        $weekWorkPct = if (($weekWorkMinutes + $weekNormalMinutes) -gt 0) {
            [Math]::Round(($weekWorkMinutes / ($weekWorkMinutes + $weekNormalMinutes)) * 100, 1)
        } else { 0 }

        Write-Host "📆 This Week's Statistics" -ForegroundColor White
        Write-Host "Work Time: $(Format-Duration -Duration (New-TimeSpan -Minutes $weekWorkMinutes))" -ForegroundColor Green
        Write-Host "Normal Time: $(Format-Duration -Duration (New-TimeSpan -Minutes $weekNormalMinutes))" -ForegroundColor Yellow
        Write-Host "Work Percentage: $weekWorkPct%" -ForegroundColor Cyan
        Write-Host ""
    }

    if ($script:CurrentSession.StartTime) {
        $currentDuration   = (Get-Date) - $script:CurrentSession.StartTime
        $currentDurationStr = Format-Duration -Duration $currentDuration
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

        # Use new Format-Duration function for enhanced time display
        $duration = New-TimeSpan -Minutes $session.DurationMinutes
        $durationStr = Format-Duration -Duration $duration

        Write-Host "$modeIcon $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor $modeColor -NoNewline
        Write-Host " - $($session.Mode)" -ForegroundColor White -NoNewline
        Write-Host " - $durationStr" -ForegroundColor Cyan
    }
}

function Clear-WorkModeStats {
    [Alias("wmh-clear")]
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    Initialize-WorkModeData

    Write-Warning "This will permanently delete all your WorkMode session history and statistics."
    Write-Warning "This action cannot be undone."
    Write-Host ""
    Write-Host "The following data will be deleted:" -ForegroundColor Red
    Write-Host "  • All session history" -ForegroundColor White
    Write-Host "  • Productivity statistics" -ForegroundColor White
    Write-Host "  • Time tracking records" -ForegroundColor White
    Write-Host ""

    $continue = Read-Host "Are you sure you want to continue? (y/N)"

    if ($continue -match '^[yY]$') {
        try {
            $timeTrackingPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.TimeTrackingFile
            
            # Create backup before clearing
            $backupPath = "$timeTrackingPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            if (Test-Path $timeTrackingPath) {
                Copy-Item -Path $timeTrackingPath -Destination $backupPath -Force
                Write-Host "✅ Backup created at: $backupPath" -ForegroundColor Green
            }

            # Clear the data while preserving structure
            $clearedData = @{
                Sessions = @()
                CurrentSession = $null
                Version = "1.0"
                ClearedOn = (Get-Date).ToString("o")
                PreviousBackup = $backupPath
            }

            # Write cleared data
            $clearedData | ConvertTo-Json -Depth 10 | Set-Content -Path $timeTrackingPath -Encoding UTF8

            # Reset current session in memory
            $script:CurrentSession.StartTime = $null
            $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()
            $script:CurrentSession.Mode = "Normal"

            Write-Host "✅ Statistics cleared successfully" -ForegroundColor Green
            Write-Host "All session history and statistics have been deleted." -ForegroundColor White
            Write-Host "You can start fresh with 'wmh-on' to begin tracking new sessions." -ForegroundColor Cyan

        } catch {
            Write-Error "Failed to clear statistics: $($_.Exception.Message)"
            
            # Attempt to restore from backup if something went wrong
            if ($backupPath -and (Test-Path $backupPath)) {
                try {
                    Copy-Item -Path $backupPath -Destination $timeTrackingPath -Force
                    Write-Host "Restored original data from backup." -ForegroundColor Yellow
                } catch {
                    Write-Error "Failed to restore backup: $($_.Exception.Message)"
                }
            }
            throw
        }
    } else {
        Write-Host "Operation cancelled. No data was deleted." -ForegroundColor Yellow
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

    # Use unified AllSites array instead of separate BlockSites and CustomSites
    $allSites = $sitesData.AllSites
    $hostessPath = $script:WorkModeConfig.HostessPath

    if (-not (Test-Path $hostessPath)) {
        throw "Hostess binary not found at: $hostessPath"
    }

    $blockedCount = 0
    foreach ($site in $allSites) {
        try {
            $checkResult = Invoke-HostessWithRetry -Arguments "has $site" -SuppressOutput $true
            if ($checkResult -is [string]) {
                # Site exists in hosts file, try to enable it
                $result = Invoke-HostessWithRetry -Arguments "on $site" -SuppressOutput $true
                if ($result -is [string]) {
                    $blockedCount++
                }
            } else {
                # Site doesn't exist, try to add it
                $addArgs = "add $site $($script:WorkModeConfig.BlockIP)"
                $result = Invoke-HostessWithRetry -Arguments $addArgs -SuppressOutput $true
                if ($result -is [string]) {
                    $blockedCount++
                }
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

    # Use unified AllSites array instead of separate BlockSites and CustomSites
    $allSites = $sitesData.AllSites
    $hostessPath = $script:WorkModeConfig.HostessPath

    if (-not (Test-Path $hostessPath)) {
        throw "Hostess binary not found at: $hostessPath"
    }

    $unblockedCount = 0
    foreach ($site in $allSites) {
        try {
            $result = Invoke-HostessWithRetry -Arguments "off $site" -SuppressOutput $true
            if ($result -is [string]) {
                $unblockedCount++
            }
        } catch {
            Write-Warning "Failed to unblock site $($site): $($_.Exception.Message)"
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

    # Check if this is the new unified format or old format
    if ($sitesData.AllSites) {
        # New unified format
        if ($site -in $sitesData.AllSites) {
            Write-Host "Site '$site' is already in the block list." -ForegroundColor Yellow
            return
        }

        # Add to AllSites array
        $sitesData.AllSites += $site
        
        # Add to Custom category
        $sitesData.Categories.Custom += $site
        
        $sitesData.LastUpdated = (Get-Date).ToString("o")
        
        Write-Host "✅ Added '$site' to block list (Custom category)" -ForegroundColor Green
    } else {
        # Old format - maintain backward compatibility
        if ($site -in $sitesData.BlockSites -or $site -in $sitesData.CustomSites) {
            Write-Host "Site '$site' is already in the block list." -ForegroundColor Yellow
            return
        }

        $sitesData.CustomSites += $site
        $sitesData.LastUpdated = (Get-Date).ToString("o")
        
        Write-Host "✅ Added '$site' to block list" -ForegroundColor Green
    }

    $sitesData | ConvertTo-Json -Depth 10 | Set-Content -Path $sitesConfigPath -Encoding UTF8
    Write-Host "The site will be blocked when WorkMode is enabled." -ForegroundColor Cyan

    if ($script:CurrentSession.Mode -eq "Work") {
        try {
            $hostessPath = $script:WorkModeConfig.HostessPath
            if (Test-Path $hostessPath) {
                $addResult = Invoke-HostessWithRetry -Arguments "add $site $($script:WorkModeConfig.BlockIP)" -SuppressOutput $true
                $onResult = Invoke-HostessWithRetry -Arguments "on $site" -SuppressOutput $true
                if ($addResult -is [string] -and $onResult -is [string]) {
                    Write-Host "Site blocked immediately (currently in WorkMode)" -ForegroundColor Green
                } else {
                    Write-Warning "Failed to block site immediately"
                }
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

    # Check if this is the new unified format or old format
    if ($sitesData.AllSites) {
        # New unified format
        if ($site -notin $sitesData.AllSites) {
            Write-Host "Site '$site' is not in the block list." -ForegroundColor Yellow
            return
        }

        # Check if site is in a non-custom category (can't remove default sites)
        $foundInCategory = $null
        foreach ($category in $sitesData.Categories.PSObject.Properties) {
            if ($site -in $category.Value) {
                $foundInCategory = $category.Name
                break
            }
        }

        if ($foundInCategory -ne "Custom") {
            Write-Host "Cannot remove '$site' - it's in the default '$foundInCategory' block list." -ForegroundColor Red
            return
        }

        # Remove from AllSites array
        $sitesData.AllSites = $sitesData.AllSites | Where-Object { $_ -ne $site }
        
        # Remove from Custom category
        $sitesData.Categories.Custom = $sitesData.Categories.Custom | Where-Object { $_ -ne $site }
        
        $sitesData.LastUpdated = (Get-Date).ToString("o")
        
        Write-Host "✅ Removed '$site' from block list (Custom category)" -ForegroundColor Green
    } else {
        # Old format - maintain backward compatibility
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
        
        Write-Host "✅ Removed '$site' from block list" -ForegroundColor Green
    }

    $sitesData | ConvertTo-Json -Depth 10 | Set-Content -Path $sitesConfigPath -Encoding UTF8

    if ($script:CurrentSession.Mode -eq "Work") {
        try {
            $hostessPath = $script:WorkModeConfig.HostessPath
            if (Test-Path $hostessPath) {
                $result = Invoke-HostessWithRetry -Arguments "off $site" -SuppressOutput $true
                if ($result -is [string]) {
                    Write-Host "Site unblocked immediately (currently in WorkMode)" -ForegroundColor Green
                } else {
                    Write-Warning "Failed to unblock site immediately"
                }
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

    # Check if this is the new unified format or old format
    if ($sitesData.AllSites) {
        # New unified format - display by categories
        Write-Host "Total Sites: $($sitesData.AllSites.Count)" -ForegroundColor Cyan
        Write-Host ""

        foreach ($category in $sitesData.Categories.PSObject.Properties) {
            $categoryName = $category.Name
            $sites = $category.Value
            
            if ($sites.Count -gt 0) {
                $color = switch ($categoryName) {
                    "SocialMedia" { "Yellow" }
                    "Entertainment" { "Cyan" }
                    "Gaming" { "Magenta" }
                    "Forums" { "Green" }
                    "Custom" { "Red" }
                    default { "White" }
                }
                
                Write-Host "$categoryName ($($sites.Count)):" -ForegroundColor $color
                foreach ($site in $sites) {
                    Write-Host "  • $site" -ForegroundColor Gray
                }
                Write-Host ""
            }
        }
    } else {
        # Old format - display as before for backward compatibility
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
}

#endregion

#region Helper Functions

function Assert-Admin {
    [CmdletBinding()]
    param()

    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        throw "Administrator privileges required. Re-run PowerShell as Administrator."
    }
}

function Format-Duration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [TimeSpan]$Duration = [TimeSpan]::Zero
    )

    # Handle null or invalid duration values
    if ($null -eq $Duration -or $Duration.TotalSeconds -lt 0) {
        return "0h 0m 0s"
    }

    # Extract hours, minutes, and seconds for enhanced time display
    $hours = [Math]::Floor($Duration.TotalHours)
    $minutes = $duration.Minutes
    $seconds = $duration.Seconds

    # Handle zero duration case
    if ($hours -eq 0 -and $minutes -eq 0 -and $seconds -eq 0) {
        return "0h 0m 0s"
    }

    # Build time components array
    $parts = @()
    if ($hours -gt 0) { $parts += "$hours" + "h" }
    if ($minutes -gt 0) { $parts += "$minutes" + "m" }
    if ($seconds -gt 0) { $parts += "$seconds" + "s" }

    # Join components with spaces, default to "0h 0m 0s" if no parts
    return if ($parts.Count -gt 0) { $parts -join " " } else { "0h 0m 0s" }
}

function Get-RunningBrowserProcesses {
    [CmdletBinding()]
    param()

    $targetProcesses = @('chrome', 'msedge', 'firefox', 'brave', 'opera', 'iexplore')
    $runningProcesses = @()

    foreach ($processName in $targetProcesses) {
        try {
            $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($processes) {
                $runningProcesses += $processes
            }
        } catch {
            # Process not found or access denied
        }
    }

    return $runningProcesses
}

function Get-RunningDistractingApps {
    [CmdletBinding()]
    param()

    # Get the list of distracting apps from configuration
    $config = Get-WorkModeConfiguration
    $targetApps = $config.DistractingApps.ProcessNames
    $runningProcesses = @()

    foreach ($processName in $targetApps) {
        try {
            $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($processes) {
                $runningProcesses += $processes
            }
        } catch {
            # Process not found or access denied
        }
    }

    return $runningProcesses
}

function Show-BrowserCloseConfirmation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Diagnostics.Process[]]$Processes
    )

    $processNames = $Processes | Select-Object -ExpandProperty ProcessName -Unique | Sort-Object
    $processList = $processNames -join ', '

    Write-Host "⚠️  Browser processes detected that may access blocked sites:" -ForegroundColor Yellow
    Write-Host "   $processList" -ForegroundColor White
    Write-Host ""
    Write-Host "These processes should be closed before blocking websites to ensure proper functionality." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Choose an option:" -ForegroundColor White
    Write-Host "  1. Attempt to close browsers gracefully (recommended)" -ForegroundColor Green
    Write-Host "  2. Skip and continue (may cause issues)" -ForegroundColor Yellow
    Write-Host "  3. Cancel operation" -ForegroundColor Red
    Write-Host ""

    $response = Read-Host "Enter your choice (1/2/3)"

    switch ($response) {
        '1' { return 'graceful' }
        '2' { return 'skip' }
        '3' { return 'cancel' }
        default {
            Write-Host "Invalid choice. Please select 1, 2, or 3." -ForegroundColor Red
            return Show-BrowserCloseConfirmation -Processes $Processes
        }
    }
}

function Close-BrowsersGracefully {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Diagnostics.Process[]]$Processes,
        [Parameter()]
        [bool]$ForceClose = $false
    )

    Write-Host "Attempting to close browsers gracefully..." -ForegroundColor Cyan
    Write-Host "Please save any unsaved work." -ForegroundColor Yellow
    Write-Host ""

    $countdown = 10
    for ($i = $countdown; $i -gt 0; $i--) {
        Write-Host "`rGrace period: $i seconds remaining..." -ForegroundColor Yellow -NoNewline
        Start-Sleep -Seconds 1
    }
    Write-Host "`rGrace period ended. Closing browsers..." -ForegroundColor Cyan

    # Try to close gracefully
    foreach ($process in $Processes) {
        try {
            $process.CloseMainWindow() | Out-Null
        } catch {
            Write-Warning "Failed to close $($process.ProcessName) gracefully"
        }
    }

    # Wait a moment for processes to close
    Start-Sleep -Seconds 3

    # Check which processes are still running
    $stillRunning = $Processes | Where-Object { -not $_.HasExited }

    if ($stillRunning -and $ForceClose) {
        Write-Host "Force-closing remaining processes..." -ForegroundColor Red
        $stillRunning | Stop-Process -Force
    } elseif ($stillRunning) {
        Write-Host "Some processes could not be closed:" -ForegroundColor Yellow
        $stillRunning | ForEach-Object { Write-Host "  - $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor White }
        return $false
    }

    Write-Host "✅ All browsers closed successfully" -ForegroundColor Green
    return $true
}

function Close-DistractingApps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Diagnostics.Process[]]$Processes,
        [Parameter()]
        [bool]$ForceClose = $false
    )

    $config = Get-WorkModeConfiguration
    $warningMessage = $config.DistractingApps.WarningMessage
    
    Write-Host $warningMessage -ForegroundColor Cyan
    Write-Host "Please save any unsaved work in these applications." -ForegroundColor Yellow
    Write-Host ""

    $countdown = 5
    for ($i = $countdown; $i -gt 0; $i--) {
        Write-Host "`rGrace period: $i seconds remaining..." -ForegroundColor Yellow -NoNewline
        Start-Sleep -Seconds 1
    }
    Write-Host "`rGrace period ended. Closing distracting apps..." -ForegroundColor Cyan

    # Try to close gracefully
    foreach ($process in $Processes) {
        try {
            $process.CloseMainWindow() | Out-Null
            Write-Host "Sent close signal to $($process.ProcessName) (PID: $($process.Id))" -ForegroundColor Gray
        } catch {
            Write-Warning "Failed to close $($process.ProcessName) gracefully"
        }
    }

    # Wait a moment for processes to close
    Start-Sleep -Seconds 3

    # Check which processes are still running
    $stillRunning = $Processes | Where-Object { -not $_.HasExited }

    if ($stillRunning -and $ForceClose) {
        Write-Host "Force-closing remaining processes..." -ForegroundColor Red
        $stillRunning | Stop-Process -Force
    } elseif ($stillRunning) {
        Write-Host "Some processes could not be closed:" -ForegroundColor Yellow
        $stillRunning | ForEach-Object { Write-Host "  - $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor White }
        return $false
    }

    Write-Host "✅ All distracting apps closed successfully" -ForegroundColor Green
    return $true
}

function Get-WorkModeConfiguration {
    [CmdletBinding()]
    param()

    Initialize-WorkModeData

    $sitesConfigPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.SitesConfigFile
    $configData = Get-Content -Path $sitesConfigPath -Raw | ConvertFrom-Json

    # Return configuration object with all settings
    return @{
        ForceCloseApps = if ($configData.ForceCloseApps -ne $null) { $configData.ForceCloseApps } else { $false }
        DistractingApps = if ($configData.DistractingApps) {
            $configData.DistractingApps
        } else {
            # Default configuration for backward compatibility
            @{
                ProcessNames = @("discord", "steam", "EpicGamesLauncher")
                ForceClose = $false
                WarningMessage = "Closing distracting apps to improve focus..."
            }
        }
    }
}

function Save-CurrentSession {
    [CmdletBinding()]
    param()

    if (-not $script:CurrentSession.StartTime) {
        return
    }

    $timeTrackingPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.TimeTrackingFile
    $data = Get-Content -Path $timeTrackingPath -Raw | ConvertFrom-Json

    # Save current session state
    $data.CurrentSession = @{
        Mode = $script:CurrentSession.Mode
        StartTime = $script:CurrentSession.StartTime.ToString("o")
        SessionId = $script:CurrentSession.SessionId
    }

    $data | ConvertTo-Json -Depth 10 | Set-Content -Path $timeTrackingPath -Encoding UTF8
}

function Restore-CurrentSession {
    [CmdletBinding()]
    param()

    $timeTrackingPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.TimeTrackingFile
    if (-not (Test-Path $timeTrackingPath)) {
        return
    }

    try {
        $data = Get-Content -Path $timeTrackingPath -Raw | ConvertFrom-Json
        if ($data.CurrentSession -and $data.CurrentSession.Mode -and $data.CurrentSession.StartTime) {
            $script:CurrentSession.Mode = $data.CurrentSession.Mode
            $script:CurrentSession.StartTime = [DateTime]::Parse($data.CurrentSession.StartTime)
            $script:CurrentSession.SessionId = $data.CurrentSession.SessionId

            Write-Host "🔄 Restored previous session: $($script:CurrentSession.Mode) (started at $($script:CurrentSession.StartTime.ToString('HH:mm:ss')))" -ForegroundColor Cyan
        }
    } catch {
        # Failed to restore session, reset to normal
        $script:CurrentSession.Mode = "Normal"
        $script:CurrentSession.StartTime = $null
        $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()
    }
}

function Get-HostessCurrentMode {
    [CmdletBinding()]
    param()

    $hostessPath = $script:WorkModeConfig.HostessPath
    if (-not (Test-Path $hostessPath)) {
        return "Unknown"
    }

    try {
        $result = & $hostessPath list | Where-Object { $_ -match "workmode" }
        if ($result) {
            return "Work"
        } else {
            return "Normal"
        }
    } catch {
        return "Unknown"
    }
}

function Sync-WorkModeState {
    [CmdletBinding()]
    param()

    $hostessMode = Get-HostessCurrentMode
    $workmodeMode = $script:CurrentSession.Mode

    if ($hostessMode -ne "Unknown" -and $hostessMode -ne $workmodeMode) {
        Write-Host "⚠️  State inconsistency detected:" -ForegroundColor Yellow
        Write-Host "   Hostess: $hostessMode" -ForegroundColor White
        Write-Host "   WorkMode: $workmodeMode" -ForegroundColor White
        Write-Host "Synchronizing with hostess state..." -ForegroundColor Cyan

        if ($hostessMode -eq "Work") {
            $script:CurrentSession.Mode = "Work"
            $script:CurrentSession.StartTime = Get-Date
            $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()
            Write-Host "✅ Synchronized to WorkMode" -ForegroundColor Green
        } else {
            $script:CurrentSession.Mode = "Normal"
            $script:CurrentSession.StartTime = $null
            $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()
            Write-Host "✅ Synchronized to NormalMode" -ForegroundColor Green
        }

        Save-CurrentSession
    }
}

function Invoke-HostessWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Arguments,

        [Parameter()]
        [int]$MaxRetries = 3,

        [Parameter()]
        [bool]$SuppressOutput = $true
    )

    $hostessPath = $script:WorkModeConfig.HostessPath
    if (-not (Test-Path $hostessPath)) {
        throw "Hostess binary not found at: $hostessPath"
    }

    $attempts = 0
    $delays = @(1, 2, 4)  # Exponential backoff: 1s, 2s, 4s

    while ($attempts -lt $MaxRetries) {
        try {
            # Split arguments into array for proper hostess command execution
            $argArray = $Arguments -split ' '

            if ($SuppressOutput) {
                # Suppress stderr to hide transient file lock warnings
                $result = & $hostessPath @argArray 2>&1 | Where-Object {
                    $_ -notmatch "The process cannot access the file because it is being used by another process" -and
                    $_ -notmatch "Unable to write to.*hosts" -and
                    $_ -notmatch "error: open.*hosts"
                }
            } else {
                $result = & $hostessPath @argArray 2>&1
            }

            # Check if hostess succeeded (exit code 0) or had acceptable warnings
            if ($LASTEXITCODE -eq 0) {
                return $result
            }

            # Check for transient file lock errors in output
            $transientError = $result -join "`n" | Select-String -Pattern "being used by another process|Unable to write to.*hosts"
            if ($transientError) {
                throw "Transient file lock detected"
            }

            # Non-transient error, don't retry
            Write-Warning "Hostess operation failed: $($result -join '`n')"
            return $result

        } catch {
            $attempts++

            if ($attempts -ge $MaxRetries) {
                Write-Warning "Hostess operation failed after $MaxRetries attempts: $($_.Exception.Message)"
                return $null
            }

            $delay = $delays[$attempts - 1]
            Write-Debug "Hostess operation failed (attempt $attempts/$MaxRetries), retrying in ${delay}s..."
            Start-Sleep -Seconds $delay
        }
    }

    return $null
}

function Get-TodayStats {
    [CmdletBinding()]
    param()

    $timeTrackingPath = Join-Path $script:WorkModeConfig.DataDir $script:WorkModeConfig.TimeTrackingFile
    $data = Get-Content -Path $timeTrackingPath -Raw | ConvertFrom-Json

    if (-not $data.Sessions) {
        return $null
    }

    $today = (Get-Date).ToString("yyyy-MM-dd")
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
        WorkTime       = Format-Duration -Duration (New-TimeSpan -Minutes $workMinutes)
        NormalTime     = Format-Duration -Duration (New-TimeSpan -Minutes $normalMinutes)
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
        # Clean up backup files created by repair operations
        $parentDir = Split-Path $dataPath -Parent
        $backupFiles = Get-ChildItem -Path $parentDir -Filter "*.backup_*" -ErrorAction SilentlyContinue

        if ($backupFiles) {
            Write-Host "🧹 Found $($backupFiles.Count) backup file(s) from repair operations:" -ForegroundColor Yellow
            foreach ($file in $backupFiles) {
                Write-Host "  • $($file.Name)" -ForegroundColor White
            }

            $response = Read-Host "Remove these backup files? (Y/n) [default: Y]"
            if ($response -match '^[nN]$') {
                Write-Host "Keeping backup files." -ForegroundColor Yellow
            } else {
                foreach ($file in $backupFiles) {
                    try {
                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                        Write-Host "✅ Removed: $($file.Name)" -ForegroundColor Green
                    } catch {
                        Write-Warning "Failed to remove $($file.Name): $($_.Exception.Message)"
                    }
                }
            }
        }

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

        # Offer to reload profile
        Write-Host "Would you like to reload your PowerShell profile to remove WorkMode commands?" -ForegroundColor Yellow
        $reloadResponse = Read-Host "Reload profile now? (Y/n) [default: Y]"

        if ($reloadResponse -notmatch '^[nN]$') {
            try {
                $profilePath = $PROFILE
                if (Test-Path $profilePath) {
                    . $profilePath
                    Write-Host "✅ Profile reloaded successfully" -ForegroundColor Green
                } else {
                    Write-Host "⚠️  Profile file not found: $profilePath" -ForegroundColor Yellow
                }
            } catch {
                Write-Warning "Failed to reload profile: $($_.Exception.Message)"
                Write-Host "You may need to restart PowerShell manually" -ForegroundColor Yellow
            }
        } else {
            Write-Host "You may need to restart PowerShell to complete the uninstallation" -ForegroundColor Yellow
        }

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
            Examples    = @("wmh-on", "wmh-on -Force", "wmh-on -Verbose")
        }
        "wmh-off" = @{
            Description = "Disable WorkMode (unblock sites, start break timer)"
            Function    = "Disable-WorkMode"
            Category    = "Core"
            Examples    = @("wmh-off", "wmh-off -Force", "wmh-off -Verbose")
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
        "wmh-clear" = @{
            Description = "Clear all WorkMode statistics and session history"
            Function    = "Clear-WorkModeStats"
            Category    = "Stats"
            Examples    = @("wmh-clear")
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
            foreach ($cmdName in $categories[$cat].Keys | Sort-Object) {
                $cmdInfo = $categories[$cat][$cmdName]
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

# Restore previous session state and synchronize with hostess
Restore-CurrentSession
Sync-WorkModeState

# Export functions
Export-ModuleMember -Function @(
    'Enable-WorkMode', 'Disable-WorkMode', 'Get-WorkModeStatus',
    'Get-ProductivityStats', 'Get-WorkModeHistory', 'Clear-WorkModeStats',
    'Add-WorkBlockSite', 'Remove-WorkBlockSite', 'Get-WorkBlockSites',
    'Update-WorkMode', 'Test-WorkModeInstallation', 'Get-WorkModeInfo',
    'Uninstall-WorkMode', 'Get-WorkModeHelp'
)

# Export aliases
Export-ModuleMember -Alias @(
    'wmh-on', 'wmh-off', 'wmh-status', 'wmh-stats', 'wmh-history', 'wmh-clear',
    'wmh-add', 'wmh-remove', 'wmh-list',
    'wmh-update', 'wmh-test', 'wmh-info', 'wmh-help', 'wmh-uninstall'
)

#endregion