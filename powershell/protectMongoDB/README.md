# Protect MongoDB Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script protects MongoDB sources, databases and collections.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'protectMongoDB'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [protectMongoDB.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/protectMongoDB/protectMongoDB.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together, then, run the main script like so:

To protect autoprotect an entire source:

```powershell
# example - adding teams from the command line
./protectMongoDB.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net `
                     -jobName 'My Job' `
                     -sourceName mongo1.mydomain.net:27017
# end example
```

To autoprotect databases:

```powershell
# example - adding teams from the command line
./protectMongoDB.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net `
                     -jobName 'My Job' `
                     -sourceName mongo1.mydomain.net:27017 `
                     -objectNames database1, database2
# end example
```

To protect specific collections:

```powershell
# example - adding teams from the command line
./protectMongoDB.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net `
                     -jobName 'My Job' `
                     -sourceName mongo1.mydomain.net:27017 `
                     -objectNames database1.collection1, database2.collection2
# end example
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

* -jobName: name of the protection job
* -sourceName: name of registered MongoDB protection source
* -objectName: (optional) one or more database or database.collection names (comma separated)
* -objectList: (optional) text file of database or database.collection names (one per line)
* -exclude: (optional) autoprotect the source and exclude objects in -objectName and -objectList

## New Job Parameters

* -policyName: (optional) name of the protection policy to use (required for a new protection job)
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/Los_Angeles' (default is 'America/New_York')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain'
* -paused: (optional) pause future runs (new job only)
* -streams: (optional) number of concurrent streams (default is 16)
