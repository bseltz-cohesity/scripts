# Protect vCloud Director vApps using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script adds a vCloud Director vApp to a new or existing SQL protection job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectvApp'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectvApp.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/protectvApp/protectvApp.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. And run the script like so:

To create a new protection job:

```powershell
# example
./protectvApp.ps1 -vip mycluster `
                  -userName myuser `
                  -domain mydomain.net `
                  -sourceName myvcd `
                  -orgName myorg `
                  -vdcName myorg_vdc1 `
                  -vappName myvapp `
                  -jobName 'my vapp job' `
                  -policyName mypolicy
# end example
```

Or to update an existing job:

```powershell
# example
./protectvApp.ps1 -vip mycluster `
                  -userName myuser `
                  -domain mydomain.net `
                  -sourceName myvcd `
                  -orgName myorg `
                  -vdcName myorg_vdc1 `
                  -vappName myvapp `
                  -jobName 'my vapp job'
# end example
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -userName: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -jobName: name of protection job to create or add to
* -sourceName: name of vCD protection source
* -orgName: name of vCD Org
* -vdcName: name of vCD virtual data center
* -vappName: name of vApp to protect

## Optional Prameters

* -tenant: (optional) impersonate a Cohesity tenant
* -policyName: (optional) name of the protection policy to use
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/Los_Angeles')
* -incrementalProtectionSlaTimeMins: (optional) default 60
* -fullProtectionSlaTimeMins: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain' (or 'Direct_Archive_Viewbox' for cloud archive direct jobs)
