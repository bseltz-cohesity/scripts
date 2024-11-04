# List Backed Up Files using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script enumerates the files that are available for restore from the specified server/job. The file list is written to an output text file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'backedUpFileList'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [backedUpFileList.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/backedUpFileList/backedUpFileList.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

List the available versions:

```powershell
./backedUpFileList.ps1 -vip mycluster `
                       -username myusername `
                       -domain mydomain.net `
                       -sourceServer server1.mydomain.net `
                       -jobName myjob `
                       -showVersions
```

Select a specific job run ID:

```powershell
./backedUpFileList.ps1 -vip mycluster `
                       -username myusername `
                       -domain mydomain.net `
                       -sourceServer server1.mydomain.net `
                       -jobName myjob `
                       -runId 123456
```

Or specify a file date (the next backup at or after the specified date will be selected)

```powershell
./backedUpFileList.ps1 -vip mycluster `
                       -username myusername `
                       -domain mydomain.net `
                       -sourceServer server1.mydomain.net `
                       -jobName myjob `
                       -fileDate '2020-04-18 18:00:00'
```

Or simply use the latest version:

```powershell
./backedUpFileList.ps1 -vip mycluster `
                       -username myusername `
                       -domain mydomain.net `
                       -sourceServer server1.mydomain.net `
                       -jobName myjob
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -sourceServer: one or more servers that were backed up (comma separated)
* -jobName: name of protection job
* -showVersions: (optional) just list available versions and exit
* -start: (optional) show versions starting at date (e.g. '07-10-2020 13:30:00')
* -end: (optional) show versions starting at date (e.g. '07-14-2020 23:59:00')
* -runId: (optional) use snapshot version with specific job run ID
* -fileDate: (optional) use snapshot version at or after date specified
* -startPath: (optional) start listing files at path (default is /)
* -noIndex: (optional) force do not use index
* -forceIndex: (optional) force use index
* -showStats: (optional) include file date and size in the output
* -newerThan: (optional) only list files that were added/modified in the last X days
