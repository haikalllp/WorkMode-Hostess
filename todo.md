# WorkMode-Hostess Improvements TODO

This document contains a comprehensive plan for addressing all issues and improvements identified in `issues/improvements1.md`. The improvements are organized into 4 epics with 21 detailed tasks, each with technical implementation details and priority levels.

## Epic 1: Configuration Architecture Overhaul

**Goal**: Simplify block list management by unifying default and custom sites into a single list and integrate app closing functionality.

### Issues Addressed:
- **Issue 1-3**: Make block list into a single list, automatically load default list, allow user to add/remove anything
- **Issue 13**: Make apps like Discord, Steam, Epic Games close when wmh-on is turning on

---

### Task 1.1: Unify Block Lists (High Priority)
**Root Cause**: Current architecture separates `BlockSites` (default) and `CustomSites` (user-added), creating unnecessary complexity.

**Technical Implementation**:
- [ ] Modify `Initialize-WorkModeData` in `WorkMode.psm1:74-82` to create unified structure we can do this by loading default block list into this AllSites:
  ```powershell
  # New structure
  @{
      AllSites = $script:DefaultBlockSites
      Categories = @{
          SocialMedia = @([...])
          Entertainment = @([...])
          Gaming = @([...])
          Forums = @([...])
          Custom = @()  # User-added sites
      }
      Version = "1.0"
      LastUpdated = (Get-Date).ToString("o")
  }
  ```
- [ ] Update `Enable-WorkSitesBlocking` (lines ~493) to use unified `AllSites` array
- [ ] Modify `Disable-WorkSitesBlocking` (lines ~535) to use unified `AllSites` array
- [ ] Update `Get-WorkBlockSites` (lines ~665) to display categorized single list
- [ ] Refactor `Add-WorkBlockSite` (lines ~579) to add to appropriate category and `AllSites`
- [ ] Refactor `Remove-WorkBlockSite` (lines ~620) to remove from both `AllSites` and category
- [ ] Update `config/work-sites.json` structure to match new unified format

**Files to Modify**: `WorkMode.psm1`, `config/work-sites.json`

---

### Task 1.2: Implement App Closing System (High Priority)
**Root Cause**: No mechanism to close distracting applications when enabling WorkMode. Currently only close web applications like brave and chrome, we need to add more closing app to like Discord, Steam and Epic Games launcher

**Technical Implementation**:
- [ ] Create `Get-RunningDistractingApps` function:
  ```powershell
  function Get-RunningDistractingApps {
      # Target processes: discord, steam, epic games launcher
      $targetApps = @("discord", "steam", "EpicGamesLauncher")
      Get-Process | Where-Object { $targetApps -contains $_.ProcessName.ToLower() }
  }
  ```
- [ ] Create `Close-DistractingApps` function with graceful shutdown:
  ```powershell
  function Close-DistractingApps {
      param([array]$Processes, [switch]$Force)
      # Attempt graceful close first, then force if needed
  }
  ```
- [ ] Integrate app closing into `Enable-WorkMode` workflow (around lines 128-154)
- [ ] Add configuration option `ForceCloseApps` in sites config (already exists)
- [ ] Add user confirmation prompt for app closing

**Files to Modify**: `WorkMode.psm1`

---

## Epic 2: Time Display & Statistics Enhancement

**Goal**: Enhance time formatting to include hours, minutes, seconds and add statistics clearing functionality.

### Issues Addressed:
- **Issue 8**: Add hours h, minutes m and seconds s to everything (stats, status, history)
- **Issue 5-6**: Add way to clear out stats with warning prompt

---

### Task 2.1: Enhance Time Formatting (Medium Priority)
**Root Cause**: Current `Format-Duration` function only shows hours and minutes.

**Technical Implementation**:
- [ ] Update `Format-Duration` function (lines 698-714):
  ```powershell
  function Format-Duration {
      param([TimeSpan]$Duration)

      $hours = [Math]::Floor($Duration.TotalHours)
      $minutes = $duration.Minutes
      $seconds = $duration.Seconds

      if ($hours -eq 0 -and $minutes -eq 0 -and $seconds -eq 0) {
          return "0h 0m 0s"
      }

      $parts = @()
      if ($hours -gt 0) { $parts += "$hours" + "h" }
      if ($minutes -gt 0) { $parts += "$minutes" + "m" }
      if ($seconds -gt 0) { $parts += "$seconds" + "s" }

      return $parts -join " "
  }
  ```
- [ ] Update `Get-ProductivityStats` to use new format (lines 378-379, 395-396, 412-413)
- [ ] Update `Get-WorkModeHistory` to use new format (lines 1029-1030)
- [ ] Test edge cases where seconds component should show

**Files to Modify**: `WorkMode.psm1`

---

### Task 2.2: Add Statistics Clearing (Medium Priority)
**Root Cause**: No mechanism to reset statistics data for fresh start.

**Technical Implementation**:
- [ ] Create `Clear-WorkModeStats` function:
  ```powershell
  function Clear-WorkModeStats {
      [Alias("wmh-clear")]
      [CmdletBinding(SupportsShouldProcess=$true)]
      param()

      Write-Warning "This will permanently delete all your WorkMode session history and statistics."
      $continue = Read-Host "Are you sure you want to continue? (y/N)"

      if ($continue -match '^[yY]$') {
          # Backup existing data
          # Clear sessions array
          # Reset current session
          Write-Host "✅ Statistics cleared successfully" -ForegroundColor Green
      }
  }
  ```
- [ ] Add to function exports in `WorkMode.psm1` (line 1545-1551)
- [ ] Add alias in `WorkMode.psd1` (line 81-90)
- [ ] Update `Get-WorkModeHelp` to include new command

**Files to Modify**: `WorkMode.psm1`, `WorkMode.psd1`

---

## Epic 3: Command Line Interface Improvements

**Goal**: Standardize parameter handling, rename test command, and add new tracking functionality.

### Issues Addressed:
- **Issue 21-22**: Change `-Force` to `--force` with `-f` alias, show correct usage on wrong arguments
- **Issue 17**: Rename `wmh-test` to `wmh-doctor`
- **Issue 35**: Add `wmh-track` to create sessions without mode change

---

### Task 3.1: Standardize Force Parameters (Medium Priority)
**Root Cause**: Inconsistent parameter naming and lack of proper error messages for invalid arguments.

**Technical Implementation**:
- [ ] Update `Enable-WorkMode` function (lines 89-94):
  ```powershell
  function Enable-WorkMode {
      [CmdletBinding()]
      [Alias("wmh-on")]
      param(
          [Alias("f")]
          [switch]$force  # lowercase, with -f alias
      )
  ```
- [ ] Update `Disable-WorkMode` function (lines 174-179) with same pattern
- [ ] Add parameter validation for invalid arguments:
  ```powershell
  # Add at beginning of each function
  if ($PSBoundParameters.Count -gt 0 -and -not $PSBoundParameters.ContainsKey('force')) {
      Write-Error "Invalid parameter. Usage: wmh-on [--force|-f]"
      return
  }
  ```
- [ ] Update all calls to use `$force` instead of `$Force`

**Files to Modify**: `WorkMode.psm1`

---

### Task 3.2: Rename Test Command (Low Priority)
**Root Cause**: `wmh-test` name doesn't clearly communicate diagnostic functionality.

**Technical Implementation**:
- [ ] Rename `Test-WorkModeInstallation` to `Invoke-WorkModeDoctor` (line 1130)
- [ ] Update alias from `wmh-test` to `wmh-doctor` (line 1132)
- [ ] Update function exports in module export list (line 1549)
- [ ] Update alias exports in `WorkMode.psd1` (line 89)
- [ ] Update `Get-WorkModeHelp` to reference new command name
- [ ] Update README.md command reference table
- [ ] Update CLAUDE.md documentation

**Files to Modify**: `WorkMode.psm1`, `WorkMode.psd1`, `README.md`, `CLAUDE.md`

---

### Task 3.3: Add Track Command (High Priority)
**Root Cause**: Users want to track current activity without changing modes.

**Technical Implementation**:
- [ ] Create `Start-WorkModeTracking` function:
  ```powershell
  function Start-WorkModeTracking {
      [Alias("wmh-track")]
      [CmdletBinding()]
      param(
          [Parameter(Mandatory=$false)]
          [ValidateSet("Work", "Normal")]
          [string]$Mode = "Work"
      )

      # Check if already tracking
      if ($script:CurrentSession.StartTime) {
          Write-Host "Already tracking a session. Use 'wmh-on' or 'wmh-off' to change mode." -ForegroundColor Yellow
          return
      }

      # Start tracking without mode change
      $script:CurrentSession.StartTime = Get-Date
      $script:CurrentSession.SessionId = [Guid]::NewGuid().ToString()
      Save-CurrentSession

      Write-Host "✅ Started tracking $Mode session" -ForegroundColor Green
  }
  ```
- [ ] Add to function exports in `WorkMode.psm1`
- [ ] Add alias in `WorkMode.psd1`
- [ ] Update `Get-WorkModeHelp`
- [ ] Add logic to prevent duplicate tracking on terminal startup

**Files to Modify**: `WorkMode.psm1`, `WorkMode.psd1`

---

## Epic 4: Installation & State Management Fixes

**Goal**: Fix installation prompts, session persistence, admin requirements, and critical bugs.

### Issues Addressed:
- **Issue 10-11**: Add reload prompts to installation scripts, show message after uninstall
- **Issue 15**: Ensure admin privilege check for installation and uninstallation
- **Issue 19**: Fix session state persistence across terminal sessions
- **Issue 32**: Fix New-TimeSpan error in wmh-status
- **Issue 39**: Fix "Invalid Command" message on module import

---

### Task 4.1: Add Installation Reload Prompts (Medium Priority)
**Root Cause**: Installation scripts don't prompt users to reload their PowerShell profile.

**Technical Implementation**:
- [ ] Modify `scripts/install-local.ps1` to add Y/N prompt at end:
  ```powershell
  Write-Host "Installation complete!" -ForegroundColor Green
  $reload = Read-Host "Would you like to reload your PowerShell profile now? (y/N)"
  if ($reload -match '^[yY]$') {
      . $PROFILE
      Write-Host "Profile reloaded. WorkMode commands are now available." -ForegroundColor Green
  } else {
      Write-Host "Please restart PowerShell or run '. $PROFILE' to use WorkMode commands." -ForegroundColor Yellow
  }
  ```
- [ ] Apply same change to `scripts/install-remote.ps1`
- [ ] Modify `Uninstall-WorkMode` to show message:
  ```powershell
  Write-Host "Uninstallation complete." -ForegroundColor Green
  Write-Host "⚠️  You may need to restart your terminal session for changes to be fully applied." -ForegroundColor Yellow
  ```

**Files to Modify**: `scripts/install-local.ps1`, `scripts/install-remote.ps1`, `WorkMode.psm1`

---

### Task 4.2: Add Admin Privilege Checks (High Priority)
**Root Cause**: No verification of administrator privileges for system-level operations.

**Technical Implementation**:
- [ ] Create `Assert-AdminForInstallation` function:
  ```powershell
  function Assert-AdminForInstallation {
      $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
      $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
      if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
          Write-Error "Administrator privileges required for installation/uninstallation."
          Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
          exit 1
      }
  }
  ```
- [ ] Add check at beginning of `scripts/install-local.ps1`
- [ ] Add check at beginning of `scripts/install-remote.ps1`
- [ ] Add check at beginning of `Uninstall-WorkMode` function

**Files to Modify**: `scripts/install-local.ps1`, `scripts/install-remote.ps1`, `WorkMode.psm1`

---

### Task 4.3: Fix Session Persistence (High Priority)
**Root Cause**: Session state not properly synchronized across different terminal instances.

**Technical Implementation**:
- [ ] Debug `Restore-CurrentSession` function (lines 855-877) for cross-terminal state:
  ```powershell
  function Restore-CurrentSession {
      # Add more robust error handling
      # Add logging for debugging
      # Ensure proper session state restoration
  }
  ```
- [ ] Enhance `Sync-WorkModeState` function to verify hostess state matches session state
- [ ] Add session validation in `Get-WorkModeStatus` to detect inconsistencies
- [ ] Test scenario: enable WorkMode in terminal A, close, open terminal B, check status

**Files to Modify**: `WorkMode.psm1`

---

### Task 4.4: Fix Format-Duration Error (High Priority)
**Root Cause**: `New-TimeSpan` parameter binding error when null values passed to `Format-Duration`.

**Technical Implementation**:
- [ ] Add null parameter validation in `Format-Duration` (lines 698-714):
  ```powershell
  function Format-Duration {
      [CmdletBinding()]
      param(
          [Parameter(Mandatory=$false)]
          [TimeSpan]$Duration = [TimeSpan]::Zero
      )

      if ($null -eq $Duration -or $Duration.TotalSeconds -lt 0) {
          return "0h 0m 0s"
      }

      # Rest of existing logic...
  }
  ```
- [ ] Debug the specific call in `Get-WorkModeStatus` (line 247) causing the error
- [ ] Add proper error handling for null duration values
- [ ] Test with various session states to ensure no more errors

**Files to Modify**: `WorkMode.psm1`

---

### Task 4.5: Fix Module Import Message (Low Priority)
**Root Cause**: "Invalid Command" message appears during module import despite successful loading.

**Technical Implementation**:
- [ ] Debug module import process by checking alias registration
- [ ] Verify `WorkMode.psd1` alias exports are correct (lines 81-90)
- [ ] Check for any syntax errors or malformed commands in module initialization
- [ ] Test clean module import in fresh PowerShell session
- [ ] Add error suppression for non-critical import messages

**Files to Modify**: `WorkMode.psm1`, `WorkMode.psd1`

---

## Implementation Priority Order

### Phase 1 (Critical Fixes - High Priority)
1. **Task 4.4**: Fix Format-Duration Error (prevents core functionality)
2. **Task 4.2**: Add Admin Privilege Checks (security requirement)
3. **Task 1.1**: Unify Block Lists (architecture improvement)
4. **Task 1.2**: Implement App Closing System (enhanced functionality)
5. **Task 3.3**: Add Track Command (user-requested feature)
6. **Task 4.3**: Fix Session Persistence (core bug)

### Phase 2 (User Experience - Medium Priority)
7. **Task 2.1**: Enhance Time Formatting
8. **Task 2.2**: Add Statistics Clearing
9. **Task 3.1**: Standardize Force Parameters
10. **Task 4.1**: Add Installation Reload Prompts

### Phase 3 (Polish - Low Priority)
11. **Task 3.2**: Rename Test Command
12. **Task 4.5**: Fix Module Import Message

---

## Testing Strategy

### Before Each Phase:
- [ ] Run existing test suite: `.\scripts\run-all-tests.ps1`
- [ ] Test core functionality: `wmh-on`, `wmh-off`, `wmh-status`
- [ ] Verify installation/uninstallation workflows

### Phase-Specific Testing:
- [ ] **Phase 1**: Focus on stability and error resolution
- [ ] **Phase 2**: Test new user experience features
- [ ] **Phase 3**: Verify documentation and naming consistency

### Regression Testing:
- [ ] Test session persistence across terminal sessions
- [ ] Verify all commands work with new parameter formats
- [ ] Check that all aliases function correctly
- [ ] Validate configuration file compatibility

---

## Notes for Implementation

### Code Quality Standards:
- Maintain existing comment-based help for all functions
- Use consistent error handling patterns
- Follow PowerShell best practices for parameter validation
- Maintain backward compatibility where possible

### Testing Requirements:
- Each task should be tested independently
- Run full test suite after each phase completion
- Manual testing required for session persistence scenarios
- Cross-terminal testing essential for state management fixes

### Documentation Updates:
- Update README.md for any command changes
- Update CLAUDE.md with new architecture details
- Ensure all new functions have proper help documentation
- Update command reference tables in documentation

---

## Completion Criteria

This TODO list will be considered complete when:
1. All 21 tasks are implemented and tested
2. All issues from `issues/improvements1.md` are resolved
3. Full test suite passes without errors
4. Documentation is updated to reflect all changes
5. Installation/uninstallation workflows are thoroughly tested
6. Session persistence works reliably across terminal sessions

*Last Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')*
