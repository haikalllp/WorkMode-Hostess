# WorkMode-Hostess 🚀

A PowerShell productivity system that helps you track time and block distracting websites during work sessions using the hostess utility.

See Hostess here - [Hostess](https://github.com/cbednarski/hostess).

## Features

- **Manual Mode Switching**: Toggle between WorkMode and NormalMode
- **Time Tracking**: Automatic tracking of time spent in each mode
- **Website Blocking**: Block distracting websites during work sessions
- **Productivity Statistics**: View insights about your work patterns
- **PowerShell Integration**: Seamlessly integrates with your PowerShell profile

## Installation

> **Important**: Make sure you're running **PowerShell 7** before proceeding with installation.
>
> Check your version: `pwsh --version`
>
> Don't have PowerShell 7? See [PowerShell 7 Installation](#powershell-7-installation) below.

### **Remote Install** - One-line install from GitHub (Recommended):
```powershell
# Run the installation command
irm https://raw.githubusercontent.com/haikalllp/WorkMode-Hostess/master/scripts/install-remote.ps1 | iex
```

### **Local Install** - For users who have cloned the repository:
```powershell
# Clone the repository (in PowerShell 7)
git clone https://github.com/haikalllp/WorkMode-Hostess.git
cd WorkMode-Hostess

# Run the installation script
.\scripts\install-local.ps1
```

### Profile Integration

⚠️ **Important**: WorkMode requires manual profile integration in your **PowerShell 7 profile**.

Add this to your PowerShell 7 profile:

```powershell
# Import WorkMode module
Import-Module "$env:USERPROFILE\Documents\PowerShell\Modules\WorkMode\WorkMode.psm1" -Force

# Show status on startup
Get-WorkModeStatus
```

To edit your PowerShell 7 profile:
```powershell
# Open PowerShell 7 profile in notepad
notepad $PROFILE

# Or if you want to edit the PowerShell 7 specific profile:
notepad "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell7_profile.ps1"
```

**Note**: The profile file will be created if it doesn't exist. Make sure you're editing the correct profile for PowerShell 7, not Windows PowerShell 5.1.

## Basic Usage

```powershell
# Start focusing (blocks websites, starts timer)
wmh-on

# Take a break (unblocks websites, starts break timer)
wmh-off

# Force enable/disable (useful for debugging or recovery)
wmh-on -Force
wmh-off -Force

# Check current status
wmh-status

# View productivity statistics
wmh-stats

# Add/remove blocked sites
wmh-add reddit.com
wmh-remove reddit.com
wmh-list
```

## Commands Reference

| Command | Alias | Description |
|---------|-------|-------------|
| `Enable-WorkMode` | `wmh-on` | Enable WorkMode (block sites, start timer) |
| `Enable-WorkMode -Force` | `wmh-on -Force` | Force enable WorkMode (bypass state checks for debugging) |
| `Disable-WorkMode` | `wmh-off` | Disable WorkMode (unblock sites, start timer) |
| `Disable-WorkMode -Force` | `wmh-off -Force` | Force disable WorkMode (bypass state checks for debugging) |
| `Get-WorkModeStatus` | `wmh-status` | Show current mode and session info |
| `Get-ProductivityStats` | `wmh-stats` | Show productivity statistics |
| `Get-WorkModeHistory` | `wmh-history` | Display recent session history |
| `Add-WorkBlockSite` | `wmh-add` | Add website to block list |
| `Remove-WorkBlockSite` | `wmh-remove` | Remove website from block list |
| `Get-WorkBlockSites` | `wmh-list` | List all blocked websites |
| `Update-WorkMode` | `wmh-update` | Update hostess binary from GitHub |
| `Test-WorkModeInstallation` | `wmh-test` | Test WorkMode installation |
| `Get-WorkModeInfo` | `wmh-info` | Display module information |
| `Get-WorkModeHelp` | `wmh-help` | Show command help |
| `Uninstall-WorkMode` | `wmh-uninstall` | Uninstall WorkMode module |

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

- **PowerShell 7.0 or higher** (Windows PowerShell 5.1 is not supported)
- Administrator privileges (for hosts file modification)
- Windows hosts file access

### PowerShell 7 Installation

If you don't have PowerShell 7 installed, you can install it using one of these methods:

#### Option 1: Winget (Recommended for Windows 10/11)
```powershell
winget install Microsoft.PowerShell
```

#### Option 2: Download from Microsoft
1. Visit [PowerShell GitHub Releases](https://github.com/PowerShell/PowerShell/releases)
2. Download the latest PowerShell-7.x.x-win-x64.msi
3. Run the installer

#### Option 3: Microsoft Store
```powershell
# Open Microsoft Store and search for "PowerShell"
# Or click this link:
start ms-store://pdp/?ProductId=9mzg1dqqq0jn
```

#### Verify PowerShell 7 Installation
```powershell
# Check your PowerShell version
pwsh --version

# Should show 7.0.0 or higher
```

#### Start PowerShell 7
- **Windows Terminal**: Right-click and select "PowerShell 7"
- **Run Dialog**: Press `Win+R` and type `pwsh`
- **Command Prompt**: Type `pwsh` and press Enter

## Troubleshooting

**Permission Denied Errors**
- Run PowerShell as Administrator for website blocking
- Check if your antivirus blocks hosts file modification

**"Blocked 0 distracting websites" Issue**
- This was a bug in the counting logic and has been fixed
- If you still see this issue, use `wmh-update` to ensure you have the latest version
- The blocking was working correctly, only the count display was affected

**Corrupted Session State**
- If WorkMode gets stuck in an inconsistent state, use the force parameter:
  ```powershell
  wmh-on -Force   # Force enable WorkMode
  wmh-off -Force  # Force disable WorkMode
  ```

**Hostess Binary Issues**
- Use `wmh-update` to download the latest binary
- Ensure `hostess.exe` is in the module directory
- If hostess commands fail with "invalid command", try updating the binary

**Profile Integration Issues**
- Verify you've added the integration code to your `$PROFILE`
- Run `. $PROFILE` to reload your profile after changes

## Advanced Usage

### Debugging and Recovery

The `-Force` parameter is useful for debugging and recovery scenarios:

```powershell
# Force enable WorkMode (bypasses state checks)
wmh-on -Force

# Force disable WorkMode (bypasses state checks)
wmh-off -Force

# Use when:
# - Session state becomes corrupted
# - WorkMode gets stuck in an inconsistent state
# - You need to bypass normal validation for debugging
```

**When to use Force parameter:**
- When WorkMode shows incorrect current mode
- After system crashes or unexpected shutdowns
- When session data becomes corrupted
- For debugging and testing purposes

### Custom Block Lists
```powershell
# Add multiple sites
"distracting1.com", "distracting2.com" | ForEach-Object {
    wmh-add $_
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
