# Gather Threat Protection Scan Results Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script gathers Threat Protection (IOC) scan results, drilling down from scans, to scan runs, to the scanned objects within each run, to the individual affected files found, and outputs the file-level detail (including file hash, severity, threat family, threat source and YARA rule matched) to a CSV file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'threatScanReport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/helios-other/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* threatScanReport.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./threatScanReport.ps1 -username myuser
```

To get results for a specific scanned object:

```powershell
./threatScanReport.ps1 -username myuser -objectName myobject
```

To limit the report to a specific scan:

```powershell
./threatScanReport.ps1 -username myuser -scanName myscan
```

To limit the report to a specific threat family:

```powershell
./threatScanReport.ps1 -username myuser -threatFamily mythreatfamily
```

To limit the report to files of a certain severity:

```powershell
./threatScanReport.ps1 -username myuser -severity critical, high
```

To include matches that have been suppressed:

```powershell
./threatScanReport.ps1 -username myuser -includeSuppressed
```

## Parameters

* -vip: (optional) defaults to helios.cohesity.com
* -username: (optional) defaults to helios
* -clusterNames: (optional) limit to one or more cluster names (comma separated, default is all clusters)
* -days: (optional) defaults to 7
* -startDate: (optional) start date of report range (e.g. '2026-09-01')
* -endDate: (optional) end date of report range (e.g. '2026-10-01')
* -scanName: (optional) limit to scans whose name matches this search term
* -objectName: (optional) limit to just one scanned object name
* -threatFamily: (optional) limit to files matching this threat family
* -severity: (optional) limit to files with this severity: critical, high, medium, low (multiple values allowed)
* -includeSuppressed: (optional) include suppressed matches (suppressed matches are excluded by default)
* -pageSize: (optional) number of records to request per API page, defaults to 100

## Output

The script writes a CSV file named `threatScanReport-<date>.csv` to the current directory, with the following columns:

* Cluster Name
* Scan Name
* Run Date
* Object Status
* Object Name
* Source Name
* Object Type
* Environment
* Affected Files Found
* File Path
* File Hash
* Severity
* Threat Family
* Threat Source
* Threat Category
* YARA Rule
* Suppressed
* Snapshot Date

Objects whose scan did not succeed get a single row showing the object status. Objects that were scanned successfully but had no matches get a single row showing 'no affected files found'.

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
