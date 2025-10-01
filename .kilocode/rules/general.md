# general.md

This file provides guidance to when working with code in this repository.

## Project Overview

WorkMode-Hostess is a PowerShell productivity system that helps users track time and block distracting websites during work sessions. It uses the hostess utility for hosts file management and provides comprehensive productivity analytics through a manual mode-switching interface.

## Guidelines

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

### Hostess Understanding
- Please run upstash-context7-mcp to better understand cbednarski/hostess by pulling its relevant documentation and code using the mcp tool.

### PowerShell Module Understanding
- Please run upstash-context7-mcp to better understand PowerShell modules development by pulling relevant documentation and code using the mcp tool.