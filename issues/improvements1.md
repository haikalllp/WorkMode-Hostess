Make block list into a single list.
Automatically load default list into this.
Makes it so that user can add/remove anything from this list, and no need for a custom list.

Add a way to clear out stats (ensure to give warning prompt)
clearing out stats will make it seems as if wmh is cleaned installed.

consider adding hour h, minutes m and seconds s, to everything, such as stats, status and history.

ensure installation of wmh on both local and remote scripts prompt user to reload with Y/N
ensure uninstallation of wmh shows message after reload "User might need to re-open terminal session for changes to properly applied" or something like that.

Make it so that apps such as known apps discord, steam, epic games are also closed when wmh is turning on.

Ensure user is in admin privillage when trying to install using any installation script and when doing wmh-uninstall

rename wmh-test into wmh-doctor and add it to wmh-help and update readme/claudemd accordingly

when running wmh-on in one elevated terminal and then close it, for some reason if user re-open a new terminal session and check status wmh is still in normal mode? even though the blocking is properly working, it should preserve these states no matter if terminal is closed. 

wmh-on -Force should instead be wmh-on --force with optional alias wmh-on -f
When user types wrong argument it should also show the correct usages. Do the same with wmh-off

Error when oding wmh-status
wmh-status
=== WorkMode Status ===
Current Mode: 🟢 Normal
Session Started: 17:49:40
Session Duration: 0h 0m
New-TimeSpan: Cannot bind parameter 'Minutes' to the target. Exception setting "Minutes": "Cannot convert null to type
"System.Int32"."

Use 'wmh-on' to start focus time or 'wmh-off' for break time

add wmh-track to create a session this way, user can immediately track current session with timer no matter if its current off or on, currently user must do wmh-on first, and then wmh-off in which it will then track both its session.
For future improvements make this run on terminal open, if current session is being tracked should not retrack.

Import module showing:
"Invalid Command" on terminal, but working fine and workmode module is properly loaded?
Import-Module "$env:USERPROFILE\Documents\PowerShell\Modules\WorkMode\WorkMode.psm1"
