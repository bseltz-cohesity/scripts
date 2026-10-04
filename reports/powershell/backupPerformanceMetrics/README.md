# Generate a Backup Performance Metrics Report using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script generates an HTML report, with graphs, of a protection job's read throughput, read latency from source, and write latency to cluster over a given time range.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'backupPerformanceMetrics'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/chart.umd.js").content | Out-File "chart.umd.js"; (Get-Content "chart.umd.js") | Set-Content "chart.umd.js"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

The report's graphs are rendered with [Chart.js](https://www.chartjs.org) (v4.4.4, MIT licensed)

## Components

* [backupPerformanceMetrics.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/backupPerformanceMetrics/backupPerformanceMetrics.ps1): the main PowerShell script
* [chart.umd.js](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/backupPerformanceMetrics/chart.umd.js): javascript chart functions
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module
* chart.umd.js: the Chart.js library used to render the graphs (see above)

Place all three files in a folder together and run the main script like so:

```powershell
# example
./backupPerformanceMetrics.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName myJob
# end example
```

To report on the last 3 days instead of the default of 1:

```powershell
# example
./backupPerformanceMetrics.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName myJob -days 3
# end example
```

To connect through Helios:

```powershell
# example
./backupPerformanceMetrics.ps1 -username myuser@mydomain.net -clusterName mycluster -jobName myJob
# end example
```

## Authentication Parameters

* -vip: (optional) name or IP of a Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -tenant: (optional) tenant organization to impersonate
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -jobName: (required) name of the protection job to report on
* -startDate: (optional) start of the reporting period, e.g. '2026-10-01' (defaults to `-days` days ago)
* -days: (optional) number of days to include in the report, starting at -startDate (defaults to 1)
* -outputPath: (optional) path to save the HTML report to (defaults to `<jobName>-performance-<date>.html` next to the script)
* -zoom: (optional) trim the leading/trailing stretches of the graphs that have no activity, keeping up to 5 minutes of zero-value padding (or more, if needed to show at least 5 minutes of graph) on each side
* -theme: (optional) `light` or `dark` color theme for the report (defaults to dark)

After the report is generated, it's opened automatically in your default browser.
