# Migrate Users and Groups using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script migrates roles, users and groups from one Cohesity cluster to another.

## Notes

This script is part of a suite of scripts to help migrate protection groups from one cluster to another. The script will copy roles, users and groups from the source cluster to the new cluster. Assuming that the migration of protection groups will occur over time, protection sources and views referenced in object restrictions for users and groups may be present, or missing at the time the script is run.

As additional protection groups are migrated, the script can be run again, and the object restrictions will be updated for any protection sources and views that were missing but are now present.

Since cleanup may have occurred on the source cluster as the migration progresses (protection sources and views may have been removed), it's important to make a cache of the source cluster's state (users, groups, roles, sources and restrictions) at the beginning of the migration, by using the `-makeCache` parameter. We can then use the cache later in the migration by using the `-useCache` parameter.

Also note that any local users will have a default password set during migration. You can use the `-defaultPassword` parameter to specify the default password.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'migrateUsersAndGroups'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [migrateUsersAndGroups.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/migrateUsersAndGroups/migrateUsersAndGroups.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

```powershell
./migrateUsersAndGroups.ps1 -sourceCluster myOldCluster `
                            -sourceUser myOldUsername `
                            -sourceDomain myOldDomain.net `
                            -targetCluster myNewCluster `
                            -targetUser myNewUsername `
                            -targetDomain myNewDomain.net
```

We can re-run the script later, after some protection groups and sources have been migrated over, to update the user and group object restrictions.

## Parameters

* -sourceCluster: name of source cluster to connect to
* -sourceUser: username for source cluster
* -sourceDomain: (optional) domain for source cluster user (defaults to local)
* -sourcePassword: (optional) password for source user
* -targetCluster: name of target cluster to connect to
* -targetUser: (optional) username for target cluster (defaults to sourceUser)
* -targetDomain: (optional) domain for target cluster user (defaults to sourceDomain)
* -targetPassword: (optional) password for target user
* -makeSourceCache: (optional) update cache of source cluster state
* -defaultPassword: (optional) default password for local users (default is 'Pa$$w0rd')
