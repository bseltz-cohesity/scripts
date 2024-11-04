# Report Protected Objects using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script creates a CSV formatted report of objects protected by Cohesity

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectedObjectReport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectedObjectReport.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/protectedObjectReport/protectedObjectReport.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together, then run the main script like so:

```powershell
./protectedObjectReport.ps1 -vip mycluster `
                            -username myusername `
                            -domain mydomain.net
```

The report will be saved as ClusterName-protectedObjectReport-date.csv

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -useApiKey: (optional) use API key authentication
* -password: (optional) will use stored password or prompt if omitted
* -objectName: (optional) object names to include (comma separated)
* -objectList: (optional) text file of object names to include (one per line)
