# CLAUDE.md — compressed guidance

Purpose: Short guidance for working on WorkMode-Hostess (PowerShell module that tracks time and blocks sites via the hostess utility).

Core files and data
- `WorkMode.psm1` — main module (single-file architecture)
- `WorkMode.psd1` — module manifest
- `config/work-sites.json` — default block lists
- Sessions: `%USERPROFILE%\Documents\PowerShell\WorkMode\time-tracking.json`

Quick commands (development & tests)
- Run all tests: `.\scripts\run-all-tests.ps1`
- Import module for dev: `Import-Module .\WorkMode.psm1 -Force`
- Local install: `.\scripts\install-local.ps1`
- Remote (simulate): `irm https://raw.githubusercontent.com/haikalllp/WorkMode-Hostess/master/scripts/install-remote.ps1 | iex`

Command conventions
- All user-facing commands use the `wmh-` prefix: e.g. `wmh-on`, `wmh-off`, `wmh-status`, `wmh-stats`, `wmh-add`, `wmh-remove`, `wmh-list`, `wmh-update`, `wmh-test`, `wmh-uninstall`.
- `-Force` is supported where noted (e.g. `wmh-on -Force`, `wmh-off -Force`) to bypass state checks and recover sessions.

Hostess integration notes
- Hostess returns: successes are String objects; failures are ErrorRecord objects.
- Use `$result -is [string]` to detect successful responses (avoid `$result -eq $true`).

Development rules & style
- Keep functionality in `WorkMode.psm1` (single-file module).
- Maintain `wmh-*` aliases and comment-based help for exported functions.
- Robust try/catch and friendly console output (Write-Host colors) for user-facing commands.

Testing guidance
- Add tests under `scripts/tests/` and use `run-all-tests.ps1`.
- Verify alias exports with: `Get-Command -Module WorkMode` after importing.

Security & environment
- Windows-only: PowerShell 7.0+ recommended. Hosts file ops require Administrator privileges.
- Do NOT auto-modify the user's `$PROFILE`.

Practical tips
- Preserve user JSON data; create backups before destructive changes.
- Use GUID-based session records and atomic file ops for integrity.

If you need more detail, open the full repository docs or the original CLAUDE.md.

MCP tools (Byterover) — when to use
- `byterover-store-knowledge`: use when learning new patterns/APIs from the codebase; encountering error solutions; finding reusable code or utilities; or after completing any significant task/plan implementation.
- `byterover-retrieve-knowledge`: use when starting a new task; before architectural decisions; when debugging to check prior solutions; or when working with unfamiliar parts of the codebase.

Follow these tool rules when using MCP tooling in this repo.

Context7 (library docs) - when to use
- Please run `upstash-context7-mcp` to better understand cbednarski/hostess by pulling its relevant documentation and code using the mcp tool.
- Please run `upstash-context7-mcp` to better understand PowerShell modules development by pulling relevant documentation and code using the mcp tool.

