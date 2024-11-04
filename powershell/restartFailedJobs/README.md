# Restart Failed Jobs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script finds failed protection groups and restarts them by running a new incremental backup that includes only the failed objects.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restartFailedJobs'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restartFailedJobs.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/restartFailedJobs/restartFailedJobs.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. And run the script like so:

```powershell
# example
./restartFailedJobs.ps1 -vip mycluster `
                        -username myuser `
                        -domain mydomain.net
# end example
```

To run the script against multiple clusters:

```powershell
# example
./restartFailedJobs.ps1 -vip mycluster1, mycluster2 `
                        -username myuser `
                        -domain mydomain.net
# end example
```

To run the script against all helios-connected clusters:

```powershell
# example
./restartFailedJobs.ps1 -username myuser@mydomain.net
# end example
```

To run the script against select helios clusters:

```powershell
# example
./restartFailedJobs.ps1 -username myuser@mydomain.net `
                        -clusterName mycluster1, mycluster2
# end example
```

## Authentication Parameters

* -vip: (optional) one or more names or IPs of Cohesity clusters (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) one or more clusters to connect to when connecting through Helios or MCM

## Other Parameters

* -jobName: (optional) names of protection jobs to include (comma separated)
* -jobList: (optional) text file of job names to include (one per line)
* -transportErrorsOnly: (optional) restart backup only for sources that failed with a transport error

## Note

By default, all protection jobs are monitored, unless you specify -jobName or -jobList.
