# List Recovery Points Per Protected Object

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script lists available local recovery points for every protected object in Cohesity.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'recoveryPoints'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* recoveryPoints.ps1: the main python script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./recoveryPoints.ps1 -vip mycluster -username myusername -domain mydomain.net
```

```text
Connected!
SQL Backup(SQL) SQLSERVER2012/namedDB on sql2012.seltzer.net
	RunDate: 2/13/20 11:00:02 PM	ExpiryDate: 2/18/20 11:00:24 PM
	RunDate: 2/12/20 11:00:01 PM	ExpiryDate: 2/17/20 11:00:25 PM
	RunDate: 2/11/20 11:00:01 PM	ExpiryDate: 2/16/20 11:00:20 PM
	RunDate: 2/10/20 11:00:00 PM	ExpiryDate: 2/15/20 11:00:22 PM
	RunDate: 2/10/20 1:04:47 PM	ExpiryDate: 2/15/20 1:05:07 PM
	RunDate: 2/9/20 11:00:01 PM	ExpiryDate: 2/14/20 11:00:23 PM
VM Backup(VMware) CentOS1
	RunDate: 2/13/20 11:00:02 PM	ExpiryDate: 2/18/20 11:00:47 PM
	RunDate: 2/12/20 11:00:01 PM	ExpiryDate: 2/17/20 11:00:41 PM
	RunDate: 2/11/20 11:00:01 PM	ExpiryDate: 2/16/20 11:00:43 PM
	RunDate: 2/10/20 11:00:00 PM	ExpiryDate: 2/15/20 11:00:40 PM
	RunDate: 2/10/20 1:04:17 PM	ExpiryDate: 2/15/20 1:04:59 PM
	RunDate: 2/9/20 11:00:01 PM	ExpiryDate: 2/14/20 11:00:45 PM
VM Backup(VMware) CentOS2
	RunDate: 2/13/20 11:00:02 PM	ExpiryDate: 2/18/20 11:00:47 PM
	RunDate: 2/12/20 11:00:01 PM	ExpiryDate: 2/17/20 11:00:41 PM
	RunDate: 2/11/20 11:00:01 PM	ExpiryDate: 2/16/20 11:00:43 PM
	RunDate: 2/10/20 11:00:00 PM	ExpiryDate: 2/15/20 11:00:40 PM
	RunDate: 2/10/20 1:04:17 PM	ExpiryDate: 2/15/20 1:04:59 PM
	RunDate: 2/9/20 11:00:01 PM	ExpiryDate: 2/14/20 11:00:45 PM
Report Saved to RecoverPoints-2-14-20_5-05-21_AM.csv
```
