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

## Quick Start

### Installation

1. **Run the installation script:**
   ```powershell
   .\scripts\install-workmode.ps1
   ```

2. **Open a new PowerShell session** to load WorkMode

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

## Configuration

### Data Directory
WorkMode stores all data in:
```
%USERPROFILE%\Documents\PowerShell\WorkMode\
├── time-tracking.json    # Session history and statistics
├── work-sites.json       # Website block lists
└── config\              # Configuration files
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
- `hostess_windows_amd64.exe` - Hostess binary for hosts file management
- `config/work-sites.json` - Default configuration files
- Updated PowerShell profile with WorkMode integration

### Requirements
- Windows PowerShell 5.1 or higher
- Administrator privileges (for hosts file modification)
- Windows hosts file access

### Files Created
- `%USERPROFILE%\Documents\PowerShell\WorkMode\` - Data directory
- `time-tracking.json` - Your session history
- `work-sites.json` - Your custom block lists

## Troubleshooting

### Common Issues

**Permission Denied Errors**
- Run PowerShell as Administrator for website blocking
- Check if your antivirus blocks hosts file modification

**Hostess Binary Not Found**
- Ensure `hostess_windows_amd64.exe` is in the module directory
- Check file permissions and antivirus settings

**Profile Integration Issues**
- Run the installation script with `-Force` to reinstall
- Check your PowerShell profile for conflicting configurations

**Resetting WorkMode**
1. Delete the WorkMode data directory: `Remove-Item -Path "$env:USERPROFILE\Documents\PowerShell\WorkMode" -Recurse`
2. Reinstall using: `.\scripts\install-workmode.ps1 -Force`

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

**Remember**: WorkMode is a tool to help you understand and improve your productivity patterns. The key is consistent use and honest self-assessment! 🎯