# Protect AWS EC2 VMs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script adds EC2 VMs to a new or existing protection group.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectEC2VMs'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectEC2VMs.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/protectEC2VMs/protectEC2VMs.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./protectEC2VMs.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -jobName 'my EC2 job' `
                    -sourceName 062441724283/myuser `
                    -policyName mypolicy `
                    -vmName vm1, vm2
```

or provide a text file with a list of VMs to protect:

```powershell
./protectEC2VMs.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -jobName 'my EC2 job' `
                    -sourceName 062441724283/myuser `
                    -policyName mypolicy `
                    -vmList .\vmlist.txt
```

## Authentication Parameters

* -vip: (optional) Cohesity cluster or MCM to connect to (defaults to helios.cohesity.com)
* -username: (optional) Cohesity username (defaults to helios)
* -domain: (optional) Active Directory domain of user (defaults to local)
* -useApiKey: (optional) Use API key for authentication
* -password: (optional) will use stored password by default
* -mcm: (optional) connect via MCM
* -clusterName: (optional) required when connecting through Helios or MCM

## EC2 Parameters

* -sourceName: name of the registered AWS source where VMs exist
* -jobName: name of protection job to create or update
* -vmName: (optional) one or more VM names to protect (comma separated)
* -vmList: (optional) text file of VM names to protect (one per line)

## Optional New Job Parameters

* -protectionType: (optional) kAgent, kNative or kSnapshotManager (default is kNative)
* -policyName: (optional) name of protection policy to use (required when creating a new job)
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/Los_Angeles')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain'
* -paused: (optional) pause future runs (new job only)
* -qosPolicy: (optional) kBackupHDD or kBackupSSD (default is kBackupHDD)
