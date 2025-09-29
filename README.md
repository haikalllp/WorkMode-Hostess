# WorkMode-Hostess 🚀

A PowerShell productivity system that helps you track time and block distracting websites during work sessions using the hostess utility.

## Features

### 🎯 Core Features
- **Manual Mode Switching**: Toggle between WorkMode and NormalMode
- **Time Tracking**: Automatic tracking of time spent in each mode
- **Website Blocking**: Block distracting websites during work sessions
- **Productivity Statistics**: View insights about your work patterns
- **Seamless Integration**: Integrates with your existing PowerShell profile

### 📊 Analytics & Insights
- **Session History**: Track all your work and break sessions
- **Daily/Weekly Statistics**: See your productivity trends
- **Time Breakdown**: View work vs normal time percentages
- **Productivity Tips**: Get insights based on your usage patterns

### 🌐 Website Management
- **Pre-configured Block List**: 20+ common distracting sites
- **Custom Sites**: Add your own distracting websites
- **Category-based**: Sites organized by category (Social Media, Entertainment, Gaming, Forums)
- **Easy Management**: Simple commands to add/remove blocked sites

## Installation

### Automated Installation

**Option 1: Remote Install (Recommended)**
One-line install directly from GitHub - no cloning required:
```powershell
irm https://raw.githubusercontent.com/haikalllp/WorkMode-Hostess/main/scripts/install-remote.ps1 | iex
```

**Option 2: Local Install (Advanced)**
For users who have cloned the repository locally:
```powershell
# First, clone the repository
git clone https://github.com/haikalllp/WorkMode-Hostess.git
cd WorkMode-Hostess

# Run the local installation script (downloads hostess from GitHub)
.\install-local.ps1
```

### Manual Installation

If you prefer manual installation or the automated scripts fail:

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/haikalllp/WorkMode-Hostess.git
   cd WorkMode-Hostess
   ```

2. **Create the module directory:**
   ```powershell
   New-Item -ItemType Directory -Path "$env:USERPROFILE\Documents\PowerShell\Modules\WorkMode" -Force
   ```

3. **Copy the module files:**
   ```powershell
   Copy-Item -Path ".\WorkMode.psm1" -Destination "$env:USERPROFILE\Documents\PowerShell\Modules\WorkMode\"
   Copy-Item -Path ".\WorkMode.psd1" -Destination "$env:USERPROFILE\Documents\PowerShell\Modules\WorkMode\"
   Copy-Item -Path ".\config" -Destination "$env:USERPROFILE\Documents\PowerShell\Modules\WorkMode\" -Recurse
   ```

4. **Download hostess binary** or use the module's update function:
   ```powershell
   # After installation, run:
   Update-WorkMode
   ```

5. **Import the module in your PowerShell profile** (see Profile Integration section below)

### Profile Integration

⚠️ **Important**: Both installation scripts are **manual-only** for profile integration. They will **NOT** automatically modify your PowerShell profile.

WorkMode requires manual integration with your PowerShell profile. Add the following code to your `$PROFILE`:

```powershell
#region WORKMODE INTEGRATION
<#
.SYNOPSIS
    WorkMode Integration for Productivity Tracking
.DESCRIPTION
    Integrates WorkMode module for time tracking and website blocking
    to help improve productivity and focus during work sessions.
#>

# Import WorkMode module
Import-Module "$env:USERPROFILE\Documents\PowerShell\Modules\WorkMode\WorkMode.psm1" -Force

# WorkMode prompt integration
$script:WorkModeStatus = $null

function Update-WorkModePromptStatus {
    if (Get-Command Get-WorkModeStatus -ErrorAction SilentlyContinue) {
        try {
            $script:WorkModeStatus = Get-WorkModeStatus -ErrorAction SilentlyContinue
        } catch {
            $script:WorkModeStatus = $null
        }
    }
}

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
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $basePrompt += " # "
    } else {
        $basePrompt += " $ "
    }

    return $basePrompt
}

# Show WorkMode status on startup
Write-Host ""
Get-WorkModeStatus
Write-Host ""
#endregion
```

To edit your profile:
```powershell
notepad $PROFILE
```

After adding the integration code, restart PowerShell or run:
```powershell
. $PROFILE
```

### Basic Usage

```powershell
# Start focusing (blocks websites, starts timer)
work-on

# Take a break (unblocks websites, starts break timer)
work-off

# Check current status
work-status

# View productivity statistics
work-stats

# Add a distracting site
add-block-site reddit.com

# Remove a site from block list
remove-block-site reddit.com

# Show all blocked sites
show-block-sites
```

## Commands Reference

### Mode Management

| Command | Alias | Description |
|---------|-------|-------------|
| `Enable-WorkMode` | `work-on` | Enable WorkMode (block sites, start work timer) |
| `Disable-WorkMode` | `work-off` | Disable WorkMode (unblock sites, start break timer) |
| `Get-WorkModeStatus` | `work-status` | Show current mode and session info |

### Statistics & History

| Command | Alias | Description |
|---------|-------|-------------|
| `Get-ProductivityStats` | `work-stats` | Show comprehensive productivity statistics |
| `Get-WorkModeHistory` | `work-history` | Display recent session history |

### Website Management

| Command | Alias | Description |
|---------|-------|-------------|
| `Add-WorkBlockSite` | `add-block-site` | Add website to block list |
| `Remove-WorkBlockSite` | `remove-block-site` | Remove website from block list |
| `Get-WorkBlockSites` | `show-block-sites` | List all blocked websites |

### Module Management

| Command | Description |
|---------|-------------|
| `Update-WorkMode` | Update hostess binary from GitHub releases |
| `Test-WorkModeInstallation` | Verify WorkMode installation and dependencies |
| `Get-WorkModeInfo` | Display WorkMode module information |

## Configuration

### Data Directory
WorkMode stores all data in:
```
%USERPROFILE%\Documents\PowerShell\WorkMode\
├── time-tracking.json    # Session history and statistics
├── work-sites.json       # Website block lists
└── config\              # Configuration files
```

### Module Directory
WorkMode module is installed in:
```
%USERPROFILE%\Documents\PowerShell\Modules\WorkMode\
├── WorkMode.psm1        # Main module file
├── WorkMode.psd1        # Module manifest
├── hostess.exe          # Hostess binary
└── config\              # Configuration files
    └── work-sites.json  # Default block list
```

### Default Blocked Sites
The system comes with pre-configured blocking for:
- **Social Media**: Facebook, Twitter, Instagram, LinkedIn, Pinterest, Tumblr, Snapchat
- **Entertainment**: YouTube, Netflix, Twitch, Imgur, TikTok
- **Gaming**: Steam, Epic Games, Discord
- **Forums**: Reddit

### Customizing Block Lists

```powershell
# Add custom distracting sites
add-block-site instagram.com
add-block-site tiktok.com

# View all blocked sites
show-block-sites

# Remove sites you don't want blocked
remove-block-site linkedin.com  # if you need LinkedIn for work
```

## How It Works

### Mode Switching
1. **WorkMode**: Blocks distracting websites using hostess, starts work timer
2. **NormalMode**: Unblocks websites, starts break timer
3. **Manual Control**: You decide when to switch modes - no automatic changes

### Time Tracking
- Each mode switch creates a new session
- Sessions are tracked with start/end times and duration
- Data is stored in JSON format for easy analysis
- Statistics show work vs normal time percentages

### Website Blocking
- Uses **hostess** utility to manage Windows hosts file
- Sites are redirected to 127.0.0.1 (localhost)
- Blocking is toggled on/off (sites remain in hosts file)
- Requires administrator privileges for hosts file modification

## Productivity Insights

### Statistics Dashboard
`work-stats` provides:

- **Overall Statistics**: Total work/normal time, productivity percentage
- **Today's Stats**: Current day's work/break time breakdown
- **Weekly Overview**: This week's productivity trends
- **Current Session**: Active session duration and mode

### Productivity Tips
The system provides insights based on your patterns:
- **70%+ work time**: "Excellent focus! You're maintaining great work habits."
- **50-70% work time**: "Good balance between work and breaks."
- **Below 50% work time**: "Consider increasing focus time for better productivity."

## Installation Details

### What Gets Installed
- `WorkMode.psm1` - Main PowerShell module
- `WorkMode.psd1` - Module manifest
- `hostess.exe` - Hostess binary for hosts file management
- `config/work-sites.json` - Default configuration files
- Manual PowerShell profile integration instructions

### Requirements
- Windows PowerShell 5.1 or higher
- Administrator privileges (for hosts file modification)
- Windows hosts file access

### Files Created
- `%USERPROFILE%\Documents\PowerShell\Modules\WorkMode\` - Module directory
- `%USERPROFILE%\Documents\PowerShell\WorkMode\` - Data directory
- `time-tracking.json` - Your session history
- `work-sites.json` - Your custom block lists

## Troubleshooting

### Common Issues

**Permission Denied Errors**
- Run PowerShell as Administrator for website blocking
- Check if your antivirus blocks hosts file modification

**Hostess Binary Not Found**
- Ensure `hostess.exe` is in the module directory
- Use `Update-WorkMode` to download the latest binary
- Check file permissions and antivirus settings

**Profile Integration Issues**
- Verify you've added the integration code to your `$PROFILE`
- Use `notepad $PROFILE` to check your profile configuration
- Run `. $PROFILE` to reload your profile after changes
- Check for conflicting prompt functions

**Resetting WorkMode**
1. Remove the module: `Remove-Item -Path "$env:USERPROFILE\Documents\PowerShell\Modules\WorkMode" -Recurse`
2. Delete data directory: `Remove-Item -Path "$env:USERPROFILE\Documents\PowerShell\WorkMode" -Recurse`
3. Reinstall using:
   - Remote install: `irm https://raw.githubusercontent.com/haikalllp/WorkMode-Hostess/main/scripts/install-remote.ps1 | iex`
   - Local install: `.\install-local.ps1 -Force`

## Advanced Usage

### Customizing the Block List
```powershell
# Batch add multiple sites
"distracting1.com", "distracting2.com" | ForEach-Object {
    add-block-site $_
}

# Export your block list
Get-Content "$env:USERPROFILE\Documents\PowerShell\WorkMode\work-sites.json" |
    ConvertFrom-Json | ConvertTo-Json -Depth 10 |
    Set-Content "my-block-list.json"
```

### Module Updates and Maintenance

```powershell
# Update hostess binary to latest version
Update-WorkMode

# Verify installation
Test-WorkModeInstallation

# Get module information
Get-WorkModeInfo

# Check for updates
Get-WorkModeInfo
```

### Analyzing Your Data
```powershell
# View raw session data
Get-Content "$env:USERPROFILE\Documents\PowerShell\WorkMode\time-tracking.json" |
    ConvertFrom-Json | Select-Object -ExpandProperty Sessions |
    Format-Table Date, Mode, DurationHours

# Calculate your own metrics
$data = Get-Content "$env:USERPROFILE\Documents\PowerShell\WorkMode\time-tracking.json" |
    ConvertFrom-Json

$totalWorkTime = ($data.Sessions | Where-Object { $_.Mode -eq "Work" } |
    Measure-Object -Property DurationHours -Sum).Sum

Write-Host "Total work hours: $totalWorkTime"
```

## Contributing

This project is designed to help improve productivity through self-awareness and manual control. Contributions are welcome!

### Ideas for Enhancement
- Pomodoro timer integration
- Daily work goals
- Export data to CSV/Excel
- Graphical reports
- Cloud synchronization
- Mobile companion app

## License

This project is open source and available under the MIT License.

## Support

If you encounter issues or have questions:
1. Check the troubleshooting section above
2. Review your PowerShell profile for conflicts
3. Ensure you have the necessary permissions
4. Verify all files are in the correct locations

---

## One-Line Remote Install

For the quickest installation without cloning, run this single command:

```powershell
irm https://raw.githubusercontent.com/haikalllp/WorkMode-Hostess/main/scripts/install-remote.ps1 | iex
```

This will download and install WorkMode automatically from GitHub, including the hostess binary and all required files.

## Local Install (Advanced Features)

If you've cloned the repository or want advanced features (logging, backup/restore, repair):

```powershell
git clone https://github.com/haikalllp/WorkMode-Hostess.git
cd WorkMode-Hostess
.\install-local.ps1 [-ShowProfileInstructions] [-Proxy "http://proxy:8080"] [-Repair] [-Uninstall] [-Offline]
```

**Local install features:**
- Automatically downloads hostess binary from GitHub releases
- Logging and diagnostics
- Backup and restore capabilities
- Repair mode for fixing broken installations
- Proxy support for corporate networks
- Uninstall functionality
- Offline mode for air-gapped environments

**Remember**: WorkMode is a tool to help you understand and improve your productivity patterns. The key is consistent use and honest self-assessment! 🎯