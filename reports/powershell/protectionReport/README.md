# Generate a Protection Report using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script finds errors and warnings for recent job runs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectionReport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectionReport.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/protectionReport/protectionReport.ps1): the main python script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script.

To show the results of all jobs (successful or not):

```powershell
./protectionReport.ps1 -vip mycluster `
                  -username myuser `
                  -domain mydomain.net `
                  -showApps `
                  -smtpServer mySMTPserver `
                  -sendTo me@mydomain.net `
                  -sendFrom them@mydomain.net
```

To show only failures and warnings:

```powershell
./protectionReport.ps1 -vip mycluster `
                  -username myuser `
                  -domain mydomain.net `
                  -showApps `
                  -failuresOnly `
                  -smtpServer mySMTPserver `
                  -sendTo me@mydomain.net `
                  -sendFrom them@mydomain.net
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
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -daysBack: (optional) number of days to include in report (default is 7 days)
* -jobTypes: (optional) filter by job type (SQL, ORacle, VMWare, etc)
* -jobName: (optional) one or more job names to include (comma separated)
* -jobList: (optional) text file of job names to include (one per line)
* -objectNames: (optional) filter on object/server name (comma separated)
* -failuresOnly: (optional) only include latest runs of jobs with errors or warnings
* -lastRunOnly: (optional) only include the latest runs
* -skipLogBackups: (optional) show only full/incremental backups
* -showObjects: (optional) show objects in jobs
* -showApps: (optional) show apps in objects
* -smtpServer: (optional) SMTP gateway to forward email through
* -smtpPort: (optional) SMTP port to use (default is 25)
* -sendTo: (optional) email addresses to send report to (comma separated)
* -sendFrom: (optional) email address to show in the from field
* -outPath: (optional) folder to write output files
* -numRuns: (optional) number of runs per query (default is 1000)
