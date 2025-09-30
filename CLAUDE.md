# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WorkMode-Hostess is a PowerShell productivity system that helps users track time and block distracting websites during work sessions. It uses the hostess utility for hosts file management and provides comprehensive productivity analytics through a manual mode-switching interface.

## Development Commands

### Testing and Verification
```powershell
# Run all tests (uses scripts/run-all-tests.ps1 which looks in scripts/tests/)
.\scripts\run-all-tests.ps1

# Or run individual tests from scripts/tests/
.\scripts\tests\test_commands.ps1
.\scripts\tests\test_import.ps1
.\scripts\tests\test_syntax.ps1

# Test WorkMode installation
wmh-test

# Verify module imports correctly
Import-Module .\WorkMode.psm1 -Force
Get-Command -Module WorkMode
```

### Installation Testing
```powershell
# Test local installation
.\scripts\install-local.ps1

# Test remote installation (simulate)
irm https://raw.githubusercontent.com/haikalllp/WorkMode-Hostess/master/scripts/install-remote.ps1 | iex
```

### Module Development
```powershell
# Import module for development
Import-Module .\WorkMode.psm1 -Force

# Reload module after changes
Remove-Module WorkMode -ErrorAction SilentlyContinue
Import-Module .\WorkMode.psm1 -Force

# Test specific functions
Get-WorkModeHelp
Get-WorkModeStatus
```

## Architecture Overview

### Core Components
1. **WorkMode.psm1** - Main module (1,457 lines) containing all functionality
2. **WorkMode.psd1** - Module manifest with exports and metadata
3. **config/work-sites.json** - Default website block lists
4. **Installation Scripts** - Remote and local deployment mechanisms

### Key Design Patterns
- **Manual Control System**: Users explicitly switch between WorkMode and NormalMode
- **Session-Based Tracking**: Each mode change creates a session with GUID-based tracking
- **JSON Configuration**: Externalized configuration for easy modification
- **Alias-Driven Interface**: All commands accessible via short `wmh-*` aliases
- **PowerShell Module Structure**: Standard PowerShell module organization

### Data Architecture
- **Time Tracking**: Sessions stored in `%USERPROFILE%\Documents\PowerShell\WorkMode\time-tracking.json`
- **Configuration**: Block lists in `work-sites.json` with categorized websites
- **Module Installation**: Standard PowerShell Modules directory structure
- **Hostess Integration**: Downloads and manages hostess binary dependency

## Critical Implementation Details

### Command Naming Convention
All commands use the `wmh-` prefix (WorkMode Hostess):
- `wmh-on` / `wmh-off` - Mode switching
- `wmh-status` / `wmh-stats` - Status and analytics
- `wmh-add` / `wmh-remove` / `wmh-list` - Website management
- `wmh-update` / `wmh-test` / `wmh-uninstall` - System management

### Installation Architecture
- **Remote Installation**: One-line install from GitHub using `irm | iex`
- **Local Installation**: For users who clone the repository
- **Manual Profile Integration**: Scripts do NOT automatically modify `$PROFILE`
- **Dependency Management**: Automatic hostess binary download from GitHub releases

### Error Handling Patterns
- Comprehensive try-catch blocks throughout
- Graceful degradation for non-critical failures
- User-friendly color-coded error messages
- Automatic backup creation before destructive operations

### Security Considerations
- Administrator privileges required for hosts file modification
- User data preservation during updates
- No automatic profile modification (manual only)
- Secure handling of user configuration files

## File Structure Conventions

```
WorkMode-Hostess/
├── WorkMode.psm1              # Main module - contains ALL functions
├── WorkMode.psd1              # Module manifest
├── scripts/
│   ├── install-local.ps1      # Local installation script
│   ├── install-remote.ps1     # Remote installation script
│   ├── run-all-tests.ps1      # Test runner that executes scripts/tests/*.ps1
│   └── tests/                 # Individual test scripts
│       ├── test_commands.ps1
│       ├── test_import.ps1
│       └── test_syntax.ps1
├── config/
│   └── work-sites.json        # Default website block lists
└── README.md                  # User documentation
```

## Development Guidelines

### Module Development
- **Single File Architecture**: All functions in WorkMode.psm1 (no separate files)
- **Alias System**: Maintain consistent `wmh-*` prefix for all user-facing commands
- **Comment-Based Help**: Every function must have comprehensive help documentation
- **Error Handling**: Use robust try-catch with user-friendly messages
- **Color Output**: Use Write-Host with colors for visual feedback

### Configuration Management
- **JSON-Based**: Store configuration in human-readable JSON files
- **User Data**: Preserve user data during updates and operations
- **Default Sites**: Maintain categorized default block lists
- **Custom Sites**: Allow user additions to default lists

### Testing Approach
- **Manual Testing**: Use test_commands.ps1 for basic verification
- **Self-Test Function**: Leverage built-in Test-WorkModeInstallation function
- **Alias Verification**: Ensure all aliases are properly exported and functional
- **Installation Testing**: Test both local and remote installation methods

### Installation Script Requirements
- **Manual Profile Integration**: Never automatically modify user's `$PROFILE`
- **GitHub Integration**: Download all files from haikalllp/WorkMode-Hostess repository
- **Hostess Dependency**: Automatically download hostess binary from GitHub releases
- **Error Recovery**: Provide clear error messages and recovery instructions

## Important Notes

### Windows-Only Limitations
- Requires Windows PowerShell 5.1+
- Depends on Windows hosts file
- Administrator privileges needed for full functionality
- No cross-platform compatibility

### User Experience Principles
- **Manual Control**: Users decide when to switch modes (no automation)
- **Visual Feedback**: Color-coded output for clear status indication
- **Progress Indicators**: Step-by-step feedback during operations
- **Comprehensive Help**: Detailed help available via `wmh-help`

### Data Persistence
- **JSON Storage**: All data stored in human-readable JSON format
- **Session Tracking**: GUID-based session management
- **Backup System**: Automatic backups before critical operations
- **Data Integrity**: Atomic file operations with error handling