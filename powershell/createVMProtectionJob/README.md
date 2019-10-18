# Create a VM Protection Job using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script creates a new VM Potection Job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'createVMProtectionJob'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* createVMProtectionJob.ps1: the main powershell script
* cohesityCluster.ps1: the multi-cluster Cohesity REST API helper module

Place the files in a folder together, then we can run the script.

Provide a text file with a list of VM Names to add to the job (e.g. myvms.txt). If not specified, the script will attempt to store the job dat in the default storage domain, (e.g. 'DefaultStorageDomain').

```powershell
./createVMProtectionJob.ps1 -vip mycluster -username admin -jobName myjob -policyName mypolicy -vCenterName vcenter.mydomain.net -startTime '23:05' -vmList ./myvms.txt

```
```text
Connected!
creating protection job myjob...
```

