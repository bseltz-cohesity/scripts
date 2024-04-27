# Gather Ransomware Anomaly Affected File List Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script gathers ransomware anomaly affected file lists and outputs to a CSV file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'heliosAnomalyFileList'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/helios-other/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* heliosAnomalyFileList.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./heliosAnomalyFileList.ps1 -username myuser@mydomain.net
```

To get the anomalies for a specific object:

```powershell
./heliosAnomalyFileList.ps1 -username myuser@mydomain.net -objectName myobject
```

## Main Parameters

* -vip: (optional) defaults to helios.cohesity.com
* -username: (optional) defaults to helios
* -days: (optional) defaults to 7
* -objectName: (optional) linit to just one object name
* -anomalyStrength: (optional) defaults to 10
* -latestPerObject: (optional) inspect only the latest anomaly for each object

## Tuning Parameters

* -sleepTime: (optional) wait X seconds between API queries (default is 1)
* -retryCount: (optional) retry API query X times (default is 10)
* -timeout: (optional) wait X seconds for API queries before retrying (default is 20)

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
