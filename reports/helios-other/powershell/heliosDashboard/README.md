# Build a Helios Cluster Health Dashboard Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script builds a self-contained HTML dashboard showing the health and status of all clusters connected to Helios: capacity, software version, patch level, upgrade status, and open critical/warning alerts.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'heliosDashboard'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/helios-other/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* heliosDashboard.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./heliosDashboard.ps1 -username myuser@mydomain.net
```

## Parameters

* -vip: (optional) defaults to helios.cohesity.com
* -username: (optional) defaults to helios
* -domain: (optional) defaults to local
* -password: (optional) uses stored password by default
* -unit: (optional) GiB or TiB (default is TiB)
* -theme: (optional) Light or Dark (default is Dark)
* -alertDays: (optional) how many days back to look for alerts (default is 7)
* -outfileName: (optional) name of the HTML file to create (defaults to heliosDashboard-yyyy-MM-dd_HHmm.html)
* -show: (optional) switch, opens the generated HTML file automatically when done

## What the dashboard shows

* Summary cards: total clusters, connected/disconnected counts, clusters with critical health, and active critical/warning alert totals
* A cluster table with health, software version, latest patch, upgrade status, node count, capacity (as a donut chart), active alert counts, and the most recent open alert per cluster
* A detail table of open critical/warning alerts, grouped by cluster (up to 3 most recent per cluster) with severity, category, first/last seen, and occurrence count

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.

If you enter the wrong password, you can re-enter the password like so:

```powershell
> . .\cohesity-api.ps1
> apiauth -helios -updatePassword
Enter your password: *********************
```
