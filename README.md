# WorkMode-Hostess 🚀

A PowerShell productivity system that helps you track time and block distracting websites during work sessions using the hostess utility.

## Features

- **Manual Mode Switching**: Toggle between WorkMode and NormalMode
- **Time Tracking**: Automatic tracking of time spent in each mode
- **Website Blocking**: Block distracting websites during work sessions
- **Productivity Statistics**: View insights about your work patterns
- **PowerShell Integration**: Seamlessly integrates with your PowerShell profile

## Installation

### Quick Install (Recommended)

**Remote Install** - One-line install from GitHub:
```powershell
irm https://raw.githubusercontent.com/haikalllp/WorkMode-Hostess/main/scripts/install-remote.ps1 | iex
```

**Local Install** - For users who have cloned the repository:
```powershell
git clone https://github.com/haikalllp/WorkMode-Hostess.git
cd WorkMode-Hostess
.\install-local.ps1
```

### Profile Integration

⚠️ **Important**: WorkMode requires manual profile integration. Add this to your `$PROFILE`:

```powershell
# Import WorkMode module
Import-Module "$env:USERPROFILE\Documents\PowerShell\Modules\WorkMode\WorkMode.psm1" -Force

# Show status on startup
Get-WorkModeStatus
```

To edit your profile:
```powershell
notepad $PROFILE
```

## Basic Usage

```powershell
# Start focusing (blocks websites, starts timer)
work-on

# Take a break (unblocks websites, starts break timer)
work-off

# Check current status
work-status

# View productivity statistics
work-stats

# Add/remove blocked sites
add-block-site reddit.com
remove-block-site reddit.com
show-block-sites
```

## Commands Reference

| Command | Alias | Description |
|---------|-------|-------------|
| `Enable-WorkMode` | `work-on` | Enable WorkMode (block sites, start timer) |
| `Disable-WorkMode` | `work-off` | Disable WorkMode (unblock sites, start timer) |
| `Get-WorkModeStatus` | `work-status` | Show current mode and session info |
| `Get-ProductivityStats` | `work-stats` | Show productivity statistics |
| `Add-WorkBlockSite` | `add-block-site` | Add website to block list |
| `Remove-WorkBlockSite` | `remove-block-site` | Remove website from block list |
| `Get-WorkBlockSites` | `show-block-sites` | List all blocked websites |
| `Update-WorkMode` | | Update hostess binary from GitHub |

## Configuration

### Data Directory
```
%USERPROFILE%\Documents\PowerShell\WorkMode\
├── time-tracking.json    # Session history and statistics
├── work-sites.json       # Website block lists
└── config\              # Configuration files
```

### Module Directory
```
%USERPROFILE%\Documents\PowerShell\Modules\WorkMode\
├── WorkMode.psm1        # Main module file
├── WorkMode.psd1        # Module manifest
├── hostess.exe          # Hostess binary
└── config\              # Configuration files
```

### Default Blocked Sites
- **Social Media**: Facebook, Twitter, Instagram, LinkedIn, Pinterest, Tumblr, Snapchat
- **Entertainment**: YouTube, Netflix, Twitch, Imgur, TikTok
- **Gaming**: Steam, Epic Games, Discord
- **Forums**: Reddit

## How It Works

1. **WorkMode**: Blocks distracting websites using hostess, starts work timer
2. **NormalMode**: Unblocks websites, starts break timer
3. **Manual Control**: You decide when to switch modes - no automatic changes
4. **Time Tracking**: Each mode switch creates a session with start/end times
5. **Statistics**: View work vs normal time percentages and productivity insights

## Requirements

- Windows PowerShell 5.1 or higher
- Administrator privileges (for hosts file modification)
- Windows hosts file access

## Troubleshooting

**Permission Denied Errors**
- Run PowerShell as Administrator for website blocking
- Check if your antivirus blocks hosts file modification

**Hostess Binary Issues**
- Use `Update-WorkMode` to download the latest binary
- Ensure `hostess.exe` is in the module directory

**Profile Integration Issues**
- Verify you've added the integration code to your `$PROFILE`
- Run `. $PROFILE` to reload your profile after changes

## Advanced Usage

### Custom Block Lists
```powershell
# Add multiple sites
"distracting1.com", "distracting2.com" | ForEach-Object {
    add-block-site $_
}

# Export your block list
Get-Content "$env:USERPROFILE\Documents\PowerShell\WorkMode\work-sites.json" |
    ConvertFrom-Json | ConvertTo-Json -Depth 10 |
    Set-Content "my-block-list.json"
```

### Data Analysis
```powershell
# View raw session data
$data = Get-Content "$env:USERPROFILE\Documents\PowerShell\WorkMode\time-tracking.json" |
    ConvertFrom-Json

$totalWorkTime = ($data.Sessions | Where-Object { $_.Mode -eq "Work" } |
    Measure-Object -Property DurationHours -Sum).Sum

Write-Host "Total work hours: $totalWorkTime"
```

## Author

**haikalllp** - [GitHub Profile](https://github.com/haikalllp)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review your PowerShell profile for conflicts
3. Ensure you have the necessary permissions
4. Verify all files are in the correct locations

---

**Remember**: WorkMode is a tool to help you understand and improve your productivity patterns. The key is consistent use and honest self-assessment! 🎯