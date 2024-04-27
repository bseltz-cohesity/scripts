# Clone a VM Protection Group using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script clones a VMware protection group.

## Notes

This script can create a copy of a VM protection group, on the same cluster, a different cluster, a different storage domain.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cloneVMProtectionGroup'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [cloneVMProtectionGroup.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cloneVMProtectionGroup/cloneVMProtectionGroup.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together and run the script like so:

To clone a group to another cluster using the same name (and keep the same selections):

```powershell
./cloneVMProtectionGroup.ps1 -sourceCluster myOldCluster `
                             -sourceUser myOldUsername `
                             -sourceDomain myOldDomain.net `
                             -targetCluster myNewCluster `
                             -targetUser myNewUsername `
                             -sourceDomain myNewDomain.net `
                             -jobName myjob
```

To clone a group to another group on the same cluster:

```powershell
./cloneVMProtectionGroup.ps1 -sourceCluster myOldCluster `
                             -sourceUser myOldUsername `
                             -sourceDomain myOldDomain.net `
                             -jobName myjob `
                             -suffix clone
```

To clone a group to another group using a different vCenter `

```powershell
./cloneVMProtectionGroup.ps1 -sourceCluster myOldCluster `
                             -sourceUser myOldUsername `
                             -sourceDomain myOldDomain.net `
                             -jobName myjob `
                             -suffix vCenterB `
                             -vCenterName vCenterB.mydomain.net `
                             -vmName myvm1
```

## Basic Parameters

* -useHelios: (optional) connect to helios
* -heliosURL: (optional) specify DNS name or IP of on-prem Helios (MCM)

* -sourceCluster: name of source cluster to connect to
* -sourceUser: username for source cluster
* -sourceDomain: (optional) domain for source cluster user (defaults to local)
* -sourcePassword: (optional) password for source user

* -targetCluster: (optional) name of target cluster to connect to (defaults to same as sourceCluster)
* -targetUser: (optional) username for target cluster (defaults to sourceUser)
* -targetDomain: (optional) domain for target cluster user (defaults to sourceDomain)
* -targetPassword: (optional) password for target user

* -jobName: name of job to clone
* -pauseOldJob

## Target Job Parameters

* -prefix: (optional) add prefix to target job name
* -suffix: (optional) add suffic to target job name (defaults to 'clone' when using same cluster)
* -newJobName: (optional) new name for target job (defaults to jobName)

* -newPolicyName: (optional) new policy name (defaults to same policy name as source job)
* -newStorageDomainName: (optional) new storage domain name (defaults to same storage domain name as source job)
* -pauseNewJob: (optional) pause new job

## VM Selections

* -vCenterName: (optional) name of vCenter for new job
* -clearObjects: (optional) clear object selections
* -vmName: (optional) names of VMs to add to new job (comma separated)
* -vmList: (optional) text file of names of VMs to add to new job (one per line)

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.

If you enter the wrong password, you can re-enter the password like so:

```powershell
> . .\cohesity-api.ps1
> apiauth -helios -updatePassword
Enter your password: *********************
```
