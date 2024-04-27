# Add Global Disk Exclusions to a VM Protection Group using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script adds global disk exclusions to an existing VMware protection group.

## Notes

Global disk exclusions are applied at the protection group level and will apply to all VMs protected by the group. Disks are specified in the format of controllerType:busNumber:unitNumber like SCSI:0:0

Valid controller types are SCSI, IDE and SATA

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'addGlobalVMDiskExclusions'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [addGlobalVMDiskExclusions.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/addGlobalVMDiskExclusions/addGlobalVMDiskExclusions.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together and run the script like so:

To add some exclusions to a job:

```powershell
./addGlobalVMDiskExclusions.ps1 -vip mycluster `
                                -username myuser `
                                -domain mydomain.net `
                                -jobName myvmjob `
                                -excludeDisk SCSI:1:0, SCSI:1:1
```

Or exclusions can be added from a list in a text file:

```powershell
./addGlobalVMDiskExclusions.ps1 -vip mycluster `
                                -username myuser `
                                -domain mydomain.net `
                                -jobName myvmjob `
                                -excludeList ./exclusions.txt
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -useApiKey: (optional) use API Key for authentication
* -password: (optional) will use stored password by default
* -jobName: (optional) comma separated list of job names to delete
* -excludeDisk: (optional) one or more exclusions (comma separated), like SCSI:1:0, SCSI:1:1
* -excludeList: (optional) text file containing exclusions (one per line)
* -replace: (optional) remove any existing exclusions (will append by default)
