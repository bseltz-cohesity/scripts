# Migrate Protection Policy using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script migrates a protection policy from one Cohesity cluster to another.

## Notes

Before attempting to migrate a protection policy, make sure you have registered remote clusters for replication and registered external targets for archival. Ideally all archive targets on the target cluster will be named the same as on the source cluster, but there are options to rename or skip thesse.

Note that cloudSpin policy is not currently supported by this script.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'migrateProtectionPolicy'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [migrateProtectionPolicy.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/migrateProtectionPolicy/migrateProtectionPolicy.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together and run the script like so:

To update all VMware protection jobs:

```powershell
./migrateProtectionPolicy.ps1 -sourceCluster myOldCluster `
                              -sourceUser myOldUsername `
                              -sourceDomain myOldDomain.net `
                              -targetCluster myNewCluster `
                              -targetUser myNewUsername `
                              -sourceDomain myNewDomain.net `
                              -policyName myPolicy
```

## Basic Parameters

* -sourceCluster: name of source cluster to connect to
* -sourceUser: username for source cluster
* -sourceDomain: (optional) domain for source cluster user (defaults to local)
* -targetCluster: name of target cluster to connect to
* -targetUser: (optional) username for target cluster (defaults to sourceUser)
* -targetDomain: (optional) domain for target cluster user (defaults to sourceDomain)
* -policyName: name of policy to migrate

## Target Policy Parameters

* -prefix: (optional) add prefix to target job name
* -suffix: (optional) add suffic to target job name
* -newPolicyName: (optional) new policy name
* -newReplicaClusterName: (optional) replace any replica that points to itself with another cluster
* -skipLocalReplica: (optional) remote any replication elements that points to iteslf
* -skipAllReplicas: (optional) remove all replication elements from policy
* -skipAllArchives: (optional) remove all archhival elements from policy
* -newTargetNames: (optional) dictionary of old target names -> new target names (see below)

## Mapping Archive Target Names

If archive target names are not the same between the source cluster and the target cluster, we can map old names to new names using the `-newTargetNames` parameter, like so:

```powershell
-newTargetNames @{'myOldTarget1' = 'myNewTarget1'; 'myOldTarget2' = 'myNewTarget2'} 
```
