# Archive Weekly Snapshot using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script archives local snapshots from the specified day of the week.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'archiveWeeklySnapshot'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [archiveWeeklySnapshot.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/archiveWeeklySnapshot/archiveWeeklySnapshot.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -archive switch to see what would be archived.

```powershell
./archiveWeeklySnapshot.ps1 -vip mycluster `
                            -username myuser `
                            -domain mydomain.net `
                            -jobNames 'SQL Backup', 'VM Backup' `
                            -vault s3 `
                            -dayOfWeek Sunday `
                            -keepFor 180
```

Then, if you're happy with the list of snapshots that will be archived, run the script again and include the -archive switch. This will execute the archive tasks.

```powershell
./archiveWeeklySnapshot.ps1 -vip mycluster `
                            -username myuser `
                            -domain mydomain.net `
                            -jobNames 'SQL Backup', 'VM Backup' `
                            -vault s3 `
                            -dayOfWeek Sunday `
                            -keepFor 180 `
                            -archive
```

## Running and Scheduling PowerShell Scripts

For additional help running and scheduling Cohesity PowerShell scripts, please see <https://github.com/bseltz-cohesity/scripts/blob/master/powershell/Running%20Cohesity%20PowerShell%20Scripts.pdf>
``
