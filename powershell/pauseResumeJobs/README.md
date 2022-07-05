# Pause and Resume Protection Jobs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script can pause, resume or show the state of a protection job.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'pauseResumeJobs'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* pauseResumeJobs.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together and run the script like so:

To show the state of a job:

```powershell
./pauseResumeJobs.ps1 -vip mycluster `
                      -username myusername `
                      -domain mydomain.net `
                      -jobName 'My Job'
```

To pause the job:

```powershell
./pauseResumeJobs.ps1 -vip mycluster `
                      -username myusername `
                      -domain mydomain.net `
                      -jobName 'My Job' `
                      -pause
```

To resume the job:

```powershell
./pauseResumeJobs.ps1 -vip mycluster `
                      -username myusername `
                      -domain mydomain.net `
                      -jobName 'My Job' `
                      -resume
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -jobname: (optional) one or more job names (comma separated)
* -joblist: (optional) text file containing job names (one per line)
* -pause: (optional) pause the job
* -resume: (optional) resume the job
* -showAll: (optional) show status of all jobs (will only show paused jobs by default)
