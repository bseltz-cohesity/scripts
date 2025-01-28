# Add and Remove Job Alert Recipients using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

Note: This script requires Cohesity 6.5 or later.

This script adds and removes alert email recipients from all protection jobs/groups on a cluster.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'jobAlertRecipients'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [jobAlertRecipients.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/jobAlertRecipients/jobAlertRecipients.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
# Command line example
./jobAlertRecipients.ps1 -vip mycluster `
                         -username myuser `
                         -domain mydomain.net `
                         -addAddress myuser1@mydomain.net, myuser2@mydomain.net `
                         -removeAddress myuser3@mydomain.net, myuser4@mydomain.net
# End example
```

If you want to just list the existing alert recipients, omit the -addAddress and -removeAddress

If you want to focus on a specific job type (SQL for example) use -jobType SQL

If you want to focus on specific jobs, you can use -jobName 'job 1', 'job 2' or you can have a text file of job names (one job name per line) and use -jobList ./myjoblist.txt

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

* -jobName: (optional) One or more job names to include (comma separated)
* -jobList: (optional) text file of job names to include (one per line)
* -jobType: (optional) filter on job type (e.g. GenericNas, O365, VMware)
* -addAddress: (optional) one or more email addresses to add (comma separated)
* -removeAddress: (optional) one or more email addresses to add (comma separated)
* -alertOnSLA: (optional) enable alerts on SLA violation  
