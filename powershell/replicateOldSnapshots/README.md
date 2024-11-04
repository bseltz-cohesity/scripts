# Replicate Old Snapshots using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script replicates existing local snapshots to a replication target. This is useful if you have recently created an replication target and want to programatically replicate existing local snapshots.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'replicateOldSnapshots'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [replicateOldSnapshots.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/replicateOldSnapshots/replicateOldSnapshots.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -commit switch to see what would be replicated.

```powershell
./replicateOldSnapshots.ps1 -vip mycluster `
                            -username myuser `
                            -domain mydomain.net `
                            -replicateTo othercluster `
                            -olderThan 1
```

Then, if you're happy with the list of snapshots that will be replicated, run the script again and include the -commit switch. This will execute the replication tasks

```powershell
./replicateOldSnapshots.ps1 -vip mycluster `
                            -username myuser `
                            -domain mydomain.net `
                            -replicateTo othercluster `
                            -olderThan 1 `
                            -commmit
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -replicateTo: name of remote cluster to replicate to
* -jobName: (optional) one or more job names (comma separated) to process (default is all jobs)
* -jobList: (optional) text file of job names (one per line) to process (default is all jobs)
* -keepFor: (optional) days to keep replica (default is same as local) from the original backup date
* -olderThan: (optional) only replicate if older than X days (default is 0)
* -newerThan: (optional) only replicate if newer than X days (default is time of cluster creation)
* -commit: (optional) actually replicate (otherwise only a test run)
* -resync: (optional) re-replicate to same target (see below!)
* -excludeLogs: (optional) do not replicate logs (logs will replicate by default)
* -numRuns: (optional) number of runs to gather per API query (default is 1000)

## About Resync

Be cautious using the -resync option. The valid reasons for using -resync are:

1) Previously replicated backups have been inadvertantly deleted from the replica cluster and you want them to replicate again
2) You want to extend the retention of the replicated backups on the replica cluster

In case #1 (where the replica does not exist), if -keepFor is used, the expiration of the replica will be `runStartTime + keepFor (days)`. If -keepFor is not used, the expiration of the replica will be the same as the local snapshot.

In case #2 (where the replica exists), if -keepFor is used, the expiration of the replica will be `increased` by the number of days specified in -keepFor, or `increased` by the number of days remaining on the local snapshot retention.

So using -resync when the replica exists can result in unintended retention of the replica. For example, for a backup that occured on April 1st and the current expiration date of the replica is May 1st, -keepFor 30 means that retention will be extended to Jun 1st (60 day retention). If you run the script again, it will be extended to Aug 1st and so on. So be careful with this! You must review the current expiration on the replica cluster and do the math to determine how many days you wish to add.
