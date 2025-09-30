# 🐛 Multiple UX/Permission issues in WorkMode Hostess

## Summary

Several usability and permission problems across `wmh-status`, `wmh-stats`, `wmh-help`, installer elevation, and admin-only execution for `wmh-on/off`. Also need safe handling when blocking sites for apps currently running.

---

## 1) `wmh-status` time display + date formatting error

### Actual

```
wmh-status
=== WorkMode Status ===
Current Mode: 🟢 Normal
No active session
Get-Date.ToString: The term 'Get-Date.ToString' is not recognized as a name of a cmdlet...
Today's Work Time: 0h 0m
Today's Normal Time: 0h 0m
Work Percentage: 0%

Use 'wmh-on' to start focus time or 'wmh-off' for break time
```

### Problems

* Uses `Get-Date.ToString` instead of `(Get-Date).ToString(...)`, causing a runtime error.
* Time granularity is too coarse; users want **hours + minutes** with totals and session detail.

### Expected

* No error; date/time formatting via `(Get-Date).ToString('yyyy-MM-dd HH:mm')`.
* Show **HHh MMm** everywhere, plus current session elapsed (if any).

### Proposed Fix

* Replace `Get-Date.ToString` with `(Get-Date).ToString(...)`.
* Standardize formatter + helper:

  ```powershell
  function Format-Duration($ts) { '{0}h {1}m' -f [int]$ts.TotalHours, $ts.Minutes }
  ```
* Output example:

  ```
  === WorkMode Status ===
  Current Mode: 🟢 Normal
  Active Session: Work (started 2025-09-29 13:42)
  Elapsed: 1h 17m
  Today:
    • Work: 3h 45m
    • Normal: 1h 10m
    • Work %: 77%
  ```

### Acceptance Criteria

* No “Get-Date.ToString” error.
* All durations shown as `Xh Ym`.
* If session active: shows “Elapsed: …”.

---

## 2) `wmh-stats` should show minutes (not just hours)

### Actual

```
Total Work Time: 0 hours
...
Work Time: 0 hours
Normal Time: 0 hours
```

### Expected

* Durations in **hours + minutes** for:

  * Overall totals
  * Today
  * This week

### Proposed Fix

* Apply `Format-Duration` everywhere.
* Example:

  ```
  📊 Overall
  Total Sessions: 3
  Work: 4h 22m
  Normal: 3h 05m
  Work %: 58%
  ```

### Acceptance Criteria

* All three sections (Overall/Today/This Week) show `Xh Ym`.

---

## 3) `wmh-help` sections render empty

### Actual

```
🎯 Core Commands
--------------

🌐 Sites Commands
---------------
...
```

(Headings present; content missing.)

### Expected

* Each section lists commands with one-line summaries.
* `wmh-help -Command <name>` shows detailed help.
* `wmh-help -Category <name>` filters correctly.
* `wmh-help -Search <text>` returns fuzzy results.

### Proposed Fix

* Populate a help registry (hashtable) with:

  * `Name`, `Category`, `Summary`, `Usage`, `Examples`.
* Render table output by category; fall back to alphabetical when no category provided.
* Verify parameter binding for `-Command`, `-Category`, `-Search`.

### Acceptance Criteria

* Default `wmh-help` shows all core categories with items.
* `-Command`, `-Category`, `-Search` each return expected scoped help.

---

## 4) Installer should **force elevation** (admin) or fail fast

### Actual

* Installer runs non-admin and warns:

  ```
  ⚠️  Not running as administrator. Some features may require admin rights for hosts file modification.
  ```
* This leads to partial installs and later runtime failures for host edits.

### Expected

* **Prompt for elevation** and re-launch elevated automatically; otherwise **fail with guidance**.
* `hostess.exe` and profile wiring done in a single elevated session.

### Proposed Fix

* Add elevation bootstrap at installer start:

  ```powershell
  if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
      ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
      Start-Process pwsh -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
      exit
  }
  ```
* If user cancels UAC, exit with actionable message.

### Acceptance Criteria

* Running the one-liner triggers UAC.
* If declined, installer exits with clear instructions.
* If accepted, installer completes and `wmh-on/off` work without permission errors.

---

## 5) Enforce **admin-only** for `wmh-on` and `wmh-off`

### Actual

* Can be invoked in a normal session; may silently fail to edit hosts.

### Expected

* `wmh-on`/`wmh-off` **refuse** to run unless elevated.

### Proposed Fix

* Add guard at function entry:

  ```powershell
  function Assert-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
      ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        throw "Administrator privileges required. Re-run PowerShell as Administrator."
    }
  }
  ```
* Call `Assert-Admin` at the top of both commands.

### Acceptance Criteria

* Non-admin call fails fast with clear error.
* Admin call succeeds.

---

## 6) Safe blocking when target apps are running

### Scenario

* User enables `wmh-on` while browsers/apps that resolve blocked domains are open.

### Expected

* Detect relevant running processes (e.g., `chrome`, `msedge`, `firefox`, etc.).
* Prompt to close; if user agrees:

  1. Grace period (e.g., 10 seconds) to save work.
  2. Attempt graceful close.
  3. If still open, **optionally** force-close (configurable), then apply hosts changes.
* Option to skip force-close and continue (documented side effects).

### Proposed Fix

* Process detection + close workflow:

  ```powershell
  $targets = 'chrome','msedge','firefox','brave'
  $procs = Get-Process | Where-Object { $targets -contains $_.Name } 
  if ($procs) {
    # prompt user; on confirm:
    $procs | ForEach-Object { $_.CloseMainWindow() | Out-Null }
    Start-Sleep -Seconds 10
    $stillOpen = $procs | Where-Object { -not $_.HasExited }
    if ($stillOpen -and $Config.ForceCloseApps) {
      $stillOpen | Stop-Process -Force
    }
  }
  # then apply hosts edits via hostess
  ```
* Add config flag: `ForceCloseApps` (default: `false`).

### Acceptance Criteria

* When browsers are open, user sees a prompt with a countdown.
* With `ForceCloseApps=false`, never force-kills.
* With `ForceCloseApps=true`, remaining processes are terminated after grace period.

---

## Environment

* OS: Windows 10/11
* PowerShell: 7.5.3
* Module path: `C:\Users\swfox\Documents\PowerShell\Modules\WorkMode`
* Hostess: v0.5.2

---

## Additional Notes

* Please also switch all duration math to `TimeSpan` to avoid rounding drift and keep week totals consistent with per-day sums.
* Consider emitting **non-zero** “Productivity Insights” only when there is at least one completed session.

---

## Checklist

* [ ] Fix `(Get-Date).ToString` usage and centralize duration formatter.
* [ ] Update `wmh-stats` to show minutes everywhere.
* [ ] Populate `wmh-help` registry; verify `-Command/-Category/-Search`.
* [ ] Installer auto-elevates or fails fast with guidance.
* [ ] `wmh-on/off` enforce admin-only.
* [ ] Implement running-app detection + close/force-close flow with config.
* [ ] Add tests for each acceptance criterion.

---

If you want, I can turn these into PR-ready diffs (functions, helper module, and installer script) next.

