# Expire Old Replicas using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script expires replicas on a remote cluster older than x days. This is useful if you have reduced your retention and want to programatically expire replicas older than the new retention period.

## Warning! This script deletes backup data! Make sure you know what you are doing before you run it

## Download the Scripts

Run these commands from PowerShell to download the scripts into the current folder:

```powershell
# Download Commands
$scriptName = 'expireOldReplicas'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [expireOldReplicas.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/expireOldReplicas/expireOldReplicas.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -expire switch to see what would be deleted.

```powershell
./expireOldReplicas.ps1 -vip mycluster `
                        -username myuser `
                        -domain mydomain.net `
                        -jobname myjob1, myjob2 `
                        -daysToKeep 14 `
                        -remoteCluster othercluster
```

Then, if you're happy with the list of replicas that will be deleted, run the script again and include the -expire switch. THIS WILL DELETE THE OLD REPLICAS!!!

```powershell
./expireOldReplicas.ps1 -vip mycluster `
                        -username myuser `
                        -domain mydomain.net `
                        -jobname myjob1, myjob2 `
                        -daysToKeep 14 `
                        -remoteCluster othercluster `
                        -expire
```

You can run the script again you should see no results, unless the Cohesity cluster is very busy. It might take some time for the replicas to actually be deleted.

Also note that if you're waiting for capacity to be freed up, it may take hours to days for the garbage collector to actually free up the space.

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -remoteCluster: name of remote cluster to expire replicas from
* -jobname: (optional) narrow scope to just the specified job(s) (comma separated)
* -daysToKeep: show/expire replicas older than this many days
* -backupType: (optional) choose one of kRegular, kFull, kLog or kSystem backup types. Default is all
* -expire: (optional) expire the snapshots (if omitted, the script will only show what 'would' be expired)
* -numRuns: (optional) page through X runs at a time (default is 1000)
* -daysBack: (optional) dig back through X days of job run history (default is 180)
