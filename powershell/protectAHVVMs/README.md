# Protect AHV VMs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script adds AHV VMs to a new or existing protection group.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectAHVVMs'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectAHVVMs.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/protectAHVVMs/protectAHVVMs.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./protectAHVVMs.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -jobName myHyperVjob `
                    -sourceName myscvmm1.mydomain.net `
                    -policyName mypolicy `
                    -vmName vm1, vm2
```

or provide a text file with a list of VMs to protect:

```powershell
./protectAHVVMs.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -jobName myHyperVjob `
                    -sourceName myscvmm1.mydomain.net `
                    -policyName mypolicy `
                    -vmList .\vmlist.txt
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## AHV Parameters

* -sourceName: name of the registered AHV source where VMs exist
* -jobName: name of protection job to create or update
* -vmName: (optional) one or more VM names to protect (comma separated)
* -vmList: (optional) text file of VM names to protect (one per line)

## Optional New Job Parameters

* -policyName: (optional) name of protection policy to use (required when creating a new job)
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/Los_Angeles')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain'
* -paused: (optional) pause future runs (new job only)
* -qosPolicy: (optional) kBackupHDD or kBackupSSD (default is kBackupHDD)
