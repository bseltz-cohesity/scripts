# Migrate SQL Protection Group using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script migrates a SQL protection group from one Cohesity cluster to another.

## Notes and Warnings

This script will only work for SQL servers registered as Physical (not VMs). The script will register SQL servers to the target cluster, thus rendering the source registrations on the source cluster broken, so there's no easy way to undo this.

If you omit the `-cleanupSourceObjects` and `-cleanupSourceObjectsAndExit` switches, the job and (broken) source registrations will be paused but left behind on the source cluster, and this is recommended in case the script fails to migrate the job to the target cluster for some reason. If a failure occurs, the script can be run again after the issue has been figured out.

After the migration is successful, you can rerun the script using the `-cleanupSourceObjectsAndExit` parameter to delete the old job and old source registrations from the source cluster. Add `-deleteOldSnapshots` if you want to delete the existing backups on the source cluster.

Alternatively, if you're comfortable that the script works fine and migrations are consistently successful, then you can include the `-cleanupSourceObjects` switch in your command, which will delete the old job and source registrations durng the migration. Again, add `-deleteOldSnapshots` if you want to delete the existing backups on the source cluster.

*DO NOT* use the `-cleanupSourceObjectsAndExit` switch until *AFTER* the migration is complete, otherwise the script will simply delete the protection group and the source registrations from the source cluster without the job having been migrated!

Also note that if a SQL server is protected by multiple protection groups, you must migrate *ALL* of the groups that protect that server. Any groups left behind on the source cluster will fail to backup that server since source registration will now be broken at the source cluster.

## Migrating Cohesity Agents

This script will attempt to register the SQL servers on the target cluster, but because the Cohesity agent on the SQL servers are already registered to the source cluster, the target registrations will only be successful if:

* The agents are detached from the source cluster, or
* The agents and clusters are configured for multi-cluster registration

### Multi-Cluster Registration

If the clusters and agents are already setup for multi-cluster registration, then you can run the migrateSQLProtectionGroup.ps1 script without the `-detachServers` switch, and the script will attempt to register the agents on the target cluster, and this should be successful. Otherwise, we need to detach the agents from the source cluster.

### Detaching the Agents

When running the migrateSQLProtectionGroup.ps1 script, you can use the `-detachServers` switch to cause the script to detach the agents. For the detach to be successful, the following are required:

* The script to be run on a Windows system
* The script operator must be logged into Windows using an Active Directory user that has admin privileges to the SQL servers
* The SQL servers must have Windows Remote Management (WinRM) enabled

If the script operator does not have admin privileges, you can use the `-exportServerList` switch to export the list of SQL servers to a text file (physicalServers.txt). The text file can be shared with another user who does have admin privileges, and they can use the text file with the [detachWindowsAgents.ps1 script](https://github.com/cohesity/community-automation-samples/tree/main/powershell/detachWindowsAgent) to detach the agents, e.g.

```powershell
./detachWindowsAgents.ps1 -serverList ./physicalServers.txt
```

After the agents are detached, the migrateSQLProtectionGroup.ps1 can be run (without the `-detachServers` switch) and the agents will be registered on the target cluster successfully.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'migrateSQLProtectionGroup'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [migrateSQLProtectionGroup.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/migrateSQLProtectionGroup/migrateSQLProtectionGroup.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

The safest way to migrate SQL protection group is to avoid destroying the protection group and sources on the source cluster. This is the default behavior of the script. Note that during migration, the sources are registered onto the target cluster, so they will be broken on the source, but by leaving the protection group behind, we will have the opportunity to retry the migration if it fails for some reason.

```powershell
./migrateSQLProtectionGroup.ps1 -sourceCluster myOldCluster `
                                -sourceUser myOldUsername `
                                -sourceDomain myOldDomain.net `
                                -targetCluster myNewCluster `
                                -targetUser myNewUsername `
                                -sourceDomain myNewDomain.net `
                                -jobName myjob
```

After the migration, we can rerun the command with the `-cleanupSourceObjectsAndExit` switch to remove the old group and sources.

```powershell
./migrateSQLProtectionGroup.ps1 -sourceCluster myOldCluster `
                                -sourceUser myOldUsername `
                                -sourceDomain myOldDomain.net `
                                -targetCluster myNewCluster `
                                -targetUser myNewUsername `
                                -sourceDomain myNewDomain.net `
                                -jobName myjob `
                                -cleanupSourceObjectsAndExit
```

Or, if you're comfortable that the script works as expected, you can perform migration and cleanup in one go, using the `-cleanupSourceObjects` switch.

```powershell
./migrateSQLProtectionGroup.ps1 -sourceCluster myOldCluster `
                                -sourceUser myOldUsername `
                                -sourceDomain myOldDomain.net `
                                -targetCluster myNewCluster `
                                -targetUser myNewUsername `
                                -sourceDomain myNewDomain.net `
                                -jobName myjob `
                                -cleanupSourceObjects
```

Note that if you want to delete existing snapshots when cleaning up, use the `-deleteOldSnapshots` along with one of the cleanup switches.

## Basic Parameters

* -sourceCluster: name of source cluster to connect to
* -sourceUser: username for source cluster
* -sourceDomain: (optional) domain for source cluster user (defaults to local)
* -sourcePassword: (optional) password for source user
* -targetCluster: name of target cluster to connect to
* -targetUser: (optional) username for target cluster (defaults to sourceUser)
* -targetDomain: (optional) domain for target cluster user (defaults to sourceDomain)
* -targetPassword: (optional) password for target user
* -tenant: (optional) organization to impersonate
* -jobName: name of job to migrate

## Target Job Parameters

* -targetNGCE: (optional) use when target cluster is NGCE
* -prefix: (optional) add prefix to target job name
* -suffix: (optional) add suffic to target job name
* -newJobName: (optional) new name for target job (defaults to jobName)
* -newPolicyName: (optional) new policy name (defaults to same policy name as source job)
* -newStorageDomainName: (optional) new storage domain name (defaults to same storage domain name as source job)
* -pauseNewJob: (optional) pause new job
* -deleteReplica: (optional) delete old replica of protection group on target cluster (will not delete the snapshots)
* -exportServerList: (optional) export list of servers in protection group (for running agent detach out of band)
* -detachServers: (optional) detach agents from source cluster

## Cleanup And Source Job Parameters

* -renameOldJob: (optional) add a suffix to the old job name
* -oldJobSuffix: (optional) specify old job suffix (defaults to current date: yyyy-MM-dd)
* -cleanupSourceObjects: (optional) delete old job and unregister servers (*destructive!*)
* -cleanupSourceObjectsAndExit: (optional) delete old job and unregister servers and exit (*destructive!*)
* -deleteOldSnapshots: (optional) delete existing snapshots when cleaning up old objects (*destrictive!*)
