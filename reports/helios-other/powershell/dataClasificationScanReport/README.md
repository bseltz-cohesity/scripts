# Gather Data Classification Scan Results Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script gathers Data Classification (DLP) scan results, drilling down from scans, to scan runs, to the scanned objects within each run, to the individual sensitive files found, and outputs the file-level detail (including which pattern was matched and its sensitivity) to a CSV file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'dataClasificationScanReport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/helios-other/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* dataClasificationScanReport.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./dataClasificationScanReport.ps1 -username myuser
```

To get results for a specific scanned object:

```powershell
./dataClasificationScanReport.ps1 -username myuser -objectName myobject
```

To limit the report to a specific scan:

```powershell
./dataClasificationScanReport.ps1 -username myuser -scanName myscan
```

To limit the report to files matching a specific pattern (e.g. Social Security Number):

```powershell
./dataClasificationScanReport.ps1 -username myuser -patternName 'Social Security'
```

To limit the report to files of a certain sensitivity:

```powershell
./dataClasificationScanReport.ps1 -username myuser -sensitivity high, medium
```

## Parameters

* -vip: (optional) defaults to helios.cohesity.com
* -username: (optional) defaults to helios
* -days: (optional) defaults to 7
* -scanName: (optional) limit to scans whose name matches this search term
* -objectName: (optional) limit to just one scanned object name
* -patternName: (optional) limit to files matching this pattern name (e.g. SSN, credit card)
* -sensitivity: (optional) limit to files with this sensitivity: none, low, medium, high (multiple values allowed)
* -pageSize: (optional) number of records to request per API page, defaults to 1000

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
