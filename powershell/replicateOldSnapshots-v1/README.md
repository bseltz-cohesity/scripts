# Replicate Old Snapshots using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script replicates existing local snapshots to a replication target. This is useful if you have recently created an replication target and want to programatically replicate existing local snapshots.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'replicateOldSnapshots-v1'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* replicateOldSnapshots-v1.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -replicate switch to see what would be replicated.

```powershell
./replicateOldSnapshots-v1.ps1 -vip mycluster `
                            -username myuser `
                            -domain mydomain.net `
                            -replicateTo othercluster `
                            -olderThan 1 `
                            -IfExpiringAfter 3
```

Then, if you're happy with the list of snapshots that will be replicated, run the script again and include the -replicate switch. This will execute the replication tasks

```powershell
./replicateOldSnapshots-v1.ps1 -vip mycluster `
                            -username myuser `
                            -domain mydomain.net `
                            -replicateTo othercluster `
                            -olderThan 1 `
                            -IfExpiringAfter 3 `
                            -replicate
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
* -keepFor: (optional) days to keep replica (default is same as local) existing age is subtracted
* -olderThan: (optional) only replicate if older than X days (default is 0)
* -newerThan: (optional) only replicate if newer than X days (default is time of cluster creation)
* -IfExpiringAfter: (optional) only replicate if there are X or more days left before expiration
* -replicate: (optional) actually replicate (otherwise only a test run)
* -resync: (optional) re-replicate to same target
* -includeLogs: (optional) replicate logs (default is to skip logs)
* -numRuns: (optional) number of runs to gather per API query (default is 1000)
