# Restart Failed Jobs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script finds failed protection groups and restarts them by running a new incremental backup that includes only the failed objects.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restartFailedJobs'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restartFailedJobs.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/restartFailedJobs/restartFailedJobs.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

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

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -password: (optional) uses stored password by default
* -useApiKey: (optional) use API key authentication
* -jobName: (optional) names of protection jobs to include (comma separated)
* -jobList: (optional) text file of job names to include (one per line)

## Note

By default, all protection jobs are monitored, unless you specify -jobName or -jobList.
