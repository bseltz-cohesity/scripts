# Expunge VM Backups with PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Warning! This script deletes backup data! Make sure you know what you are doing before you run it

This powershell script searches for a VM, and deletes all backups of that VM, including the local snapshots and archives.

If you run the script without the -delete switch, the script will only display what it would delete. Use the -delete switch to actually perform the deletions.

Deletions will be logged to scriptPath/expungeVMLog-date.txt

## Download the Script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'expungeVM'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [expungeVM.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/expungeVM/expungeVM.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

```powershell
./expungeVM.ps1 -vip mycluster -username myusername -domain mydomain.net -vmName myvm
```

First, run the script WITHOUT the -delete switch to see what would be deleted. When you are happy for the script to actually delete what was displayed, rerun the command with the -delete switch

Please note that there may be some delay before the deletions are reflected in subsequent script run output.

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain (defaults to 'local')
* -vmName: (optional) one or more vm names (comma separated)
* -vmList: (optional) text file with vm names (one per line)
* -jobName: (optional) limit search to specific job name (default is all jobs)
* -olderThan: (optional) only delete snapshots/archives older than X days (defaults to 0)
* -delete: (optional) if omitted, script will only display what would be deleted
