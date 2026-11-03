# Chart Storage Growth Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Note: Please use the download commands below to download the script

This PowerShell script gathers storage usage statistics from a Cohesity cluster and charts them over time, using a JQuery Chart.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'storageChart'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/chart.umd.js").content | Out-File "chart.umd.js"; (Get-Content "chart.umd.js") | Set-Content "chart.umd.js"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [storageChart.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/storageChart/storageChart.ps1): the main PowerShell script
* [chart.umd.js](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/storageChart/chart.umd.js): javascript chart functions
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```powershell
.\storageChart.ps1 -vip mycluster -username myuser -domain mydomain.net -days 100
Connected!
Gathering Storage Statistics...
Writing Output to /scripts/powershell/storageGrowth.html
```

Your browser should open and display the chart of storage growth.

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -helios: (optional) connect through MCM/Helios OnPrem
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -days: (optional) number of days of storage statistics to display (default is 60)
* -outputPath:: (optional) output file path (default is ./storageChart.html)
* -theme: (optional) light or dark (default is dark)
