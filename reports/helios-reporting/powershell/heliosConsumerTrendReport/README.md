# Helios Storage Consumption Trend Report using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script pulls the Helios **Storage Consumption by Views** and **Storage Consumption by Protection Groups** reports for a run of consecutive calendar months, and pivots the results into a single monthly trend report: one row per view / protection group, with columns for `dataIngestedRetained` and `scRetained` for each month, plus scRetained growth columns. It can also write an HTML report with a chart of scRetained over time per entity.

It authenticates to Helios once and reuses that session across every cluster / month / report combination through a shared runspace pool, instead of re-authenticating for each call.

## Download the script

`cohesity-api.ps1` is the shared Cohesity REST API helper module used by all of these PowerShell samples. Run this from PowerShell to download it into your current directory:

```powershell
# Download Commands
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

Place `heliosConsumerTrendReport.ps1` in the same folder as `cohesity-api.ps1`.

## Components

* heliosConsumerTrendReport.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module (required)

Run the main script like so:

```powershell
./heliosConsumerTrendReport.ps1 -username myusername@mydomain.net
```

By default this pulls the last 12 complete calendar months for every self-managed cluster connected to Helios. CCS regions are never included - CCS has neither views nor protection groups, so there's nothing for these two reports to return there.

## Report names

The script looks up two Helios reports by their exact title: **Storage Consumption by Views** and **Storage Consumption by Protection Groups**. If your Helios tenant has these reports under slightly different titles, edit the `$reportConfigs` array near the top of the script.

## Parameters

* -vip: (optional) defaults to helios.cohesity.com
* -username: (optional) defaults to helios
* -tenant: (optional) organization to impersonate
* -EntraId: (optional) authenticate via Entra ID (OIDC) instead of an API key
* -startDate: (optional) first day of the first month to retrieve, e.g. '2025-10-01'. Defaults to `numMonths` back from the last completed calendar month
* -numMonths: (optional) number of consecutive calendar months to retrieve (default is 12)
* -clusterNames: (optional) limit report to one or more cluster names or IDs (comma separated)
* -timeZone: (optional) default is 'America/New_York'
* -outputPath: (optional) path to write output files (default is '.')
* -timeoutSeconds: (optional) time to wait for each API response before timeout (default is 600)
* -MaxRunspaces: (optional) max number of parallel threads in the shared runspace pool (default is 20)
* -retryCount: (optional) extra retry passes for any cluster/month/report call that comes back with an error (default is 2)
* -units: (optional) MiB or GiB - unit to convert all byte values to in the trend report (default is MiB)
* -exportRawData: (optional) also write the raw, un-pivoted monthly rows for each report (in bytes, unconverted) - one CSV per report
* -htmlReport: (optional) also write an HTML report with a scRetained-over-time chart per view / protection group
* -progress: (optional) print a line for each cluster/month/report call as it completes

## Output files

Written to `-outputPath` (default is the current directory):

* `Storage Consumption Trend_<firstMonth>_<lastMonth>_<units>.csv` - the pivoted trend report (always written)
* `Storage Consumption Trend_<firstMonth>_<lastMonth>_<units>.html` - one chart per entity, with a search box and category filter (only with `-htmlReport`)
* `Storage Consumption by Views_raw_<firstMonth>_<lastMonth>.csv` and `Storage Consumption by Protection Groups_raw_<firstMonth>_<lastMonth>.csv` - the unmodified, un-pivoted monthly rows straight from each report, in bytes (only with `-exportRawData`)

## Examples

### Basic usage

```powershell
# Last 12 complete calendar months, all clusters, MiB
./heliosConsumerTrendReport.ps1 -username myusername@mydomain.net
```

### Choosing the month range

```powershell
# Last 6 months instead of 12
./heliosConsumerTrendReport.ps1 -username myusername@mydomain.net `
                                -numMonths 6

# A specific 12-month window starting January 2025
./heliosConsumerTrendReport.ps1 -username myusername@mydomain.net `
                                -startDate '2025-01-01' `
                                -numMonths 12
```

### Units

```powershell
# Report values in GiB instead of the default MiB
./heliosConsumerTrendReport.ps1 -username myusername@mydomain.net `
                                -units GiB
```

### Cluster selection

```powershell
# Single cluster
./heliosConsumerTrendReport.ps1 -username myusername@mydomain.net `
                                -clusterNames 'cluster1'

# Multiple clusters
./heliosConsumerTrendReport.ps1 -username myusername@mydomain.net `
                                -clusterNames 'cluster1', 'cluster2', 'cluster3'
```

### HTML report and raw data

```powershell
# Also produce the HTML chart report
./heliosConsumerTrendReport.ps1 -username myusername@mydomain.net `
                                -htmlReport

# Also keep the raw, un-pivoted monthly data (in bytes) for both reports
./heliosConsumerTrendReport.ps1 -username myusername@mydomain.net `
                                -exportRawData

# Show progress as each cluster/month/report call completes
./heliosConsumerTrendReport.ps1 -username myusername@mydomain.net `
                                -progress
```

### Putting it together

```powershell
# 24 months in GiB, with the HTML report, progress shown
./heliosConsumerTrendReport.ps1 -username myusername@mydomain.net `
                                -numMonths 24 `
                                -units GiB `
                                -htmlReport `
                                -progress `
                                -outputPath 'C:\Reports\StorageTrend'
```

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon (settings) -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
