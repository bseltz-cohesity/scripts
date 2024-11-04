# Create ServiceNow Incident Tickets for Failed Protection Jobs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script creates ServiceNow incidents for protection jobs that have failed X times in a row,

## Prerequisits

This script requires the ServiceNow PowerShell modeule. To install it, open PowerShell and run the foollowing command:

```powershell
Install-Module servicenow 
```

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'snowReportStrikes'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [snowReportStrikes.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/snowReportStrikes/snowReportStrikes.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. And run the script like so:

```powershell
# example
./snowReportStrikes.ps1 -vip helios.cohesity.com `
                        -username myuser `
                        -domain mydomain.net `
                        -snowUrl myaccount.service-now.com `
                        -snowUser mysnowuser `
                        -snowcreds mycred.xml 
                        -strikes 3
# end example
```

## Parameters

* -vip: (optional name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: name of user to connect to Cohesity
* -domain: (optional) your AD domain (defaults to local)
* -snowUrl: url of serviceNow portal (e.g. myacct.service-now.com)
* -snowUser: username in service now to use for creating incidents
* -snowCreds: (optional) XML file containing service now credentials (defaults to snowcreds.xml)
* -strikes: (optional) number of failed job runs before creating incident (default is 3)

## ServiceNow Credentials

To store your ServiceNow credentials, open PowerShell and run the following command:

```powershell
get-credential | Export-Clixml -Path snowcreds.xml
```

You will be prompted for your ServiceNow username and password. These credentials will be stored for later use.
