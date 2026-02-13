# Protect Ccs M365 Groups using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script protects Ccs M365 Groups from a CSV.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectCcsM365GroupsCSV'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectCcsM365GroupsCSV.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/protectCcsM365GroupsCSV/protectCcsM365GroupsCSV.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Create a CSV file (or export from M365) containing the Groups to protect. The two CSV columns that are required for this script are name and webUrl. So for example, our CSV file might look like this:

```text
name,smtpAddress
My-Group,My-Group@mydomain.onmicrosoft.com
Another-Group,Another-Group@mydomain.onmicrosoft.com
```

Place both files in a folder together and run the main script like so:

```powershell
./protectCcsM365GroupsCSV.ps1 -policyName Gold `
                             -sourceName mydomain.onmicrosoft.com `
                             -csvFile ./Groups.csv
```

## Parameters

* -username: (optional) used for password storage only (default is 'Ccs')
* -region: specify region (e.g. us-east-2)
* -sourceName: name of registered M365 protection source
* -policyName: name of protection policy to use
* -csvFile: name of CSV file to impport
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/New_York')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -pageSize: (optional) limit number of objects returned pr page (default is 50000)
* -useMBS: (optional) use Microsoft 365 Backup Storage

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
