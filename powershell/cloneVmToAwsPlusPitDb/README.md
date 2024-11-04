# Clone a VMware VM Running SQL to AWS EC2 and then restore a SQL DB

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to perform a clone of a VMware VM to AWS EC2, and then perform a SQL database recovery onto it.

## Warning

This script can overwrite production data if you ask it to. Make sure you know what you are doing and test thoroughly before using in production!!!

## Download the scripts

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
$relative = 'powershell'
$scriptName = 'cloneVmToAwsPlusPitDb'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$relative/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'cloneVmToAws'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$relative/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'addCustomHostMapping'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$relative/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'unregisterPhysical'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$relative/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'registerPhysical'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$relative/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$relative = 'sql'
$scriptName = 'registerSQL'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$relative/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'restoreSQLDBs'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$relative/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Notes

The scenario covered by this script is that the customer has backed up a SQL VM (using a VM backup job) and has also performed SQL backups of the databases and transaction logs. The customer wants to recover the VM into EC2 (for disaster recovery) and then recover the databases and replay the transaction logs to the latest point in time.

This wrapper script calls various scripts to do the following:

* Clone a VMware VM to AWS EC2
* Unregster the unwanted auto-registered IP address of tje cloned VM
* Add a customer host mapping to Cohesity for the new VM
* Register the new VM as a physical SQL protection source
* Restore SQL databases to the latest point in time available from a SQL backup

Edit the cloneVmToAwsPlusPitDb.ps1 and populate the parameters at the top of the file, then run .\cloneVmToAwsPlusPitDb.ps1 to start the process.
