# Report Storage Consumption using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script reports per-job and per-view storage consumption. The script will generate an html report and send it to email recipients. Per-job and per-view storage statistics are available in Cohesity 6.4 and later.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'storageReport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [storageReport.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/storageReport/storageReport.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the script like so:

```powershell
./storageReport.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -smtpServer 192.168.1.95 `
                    -sendTo myusername@mydomain.net `
                    -sendFrom mycluster@mydomain.net
```

## Authentication Parameters

* -vip: (optional) one or more names or IPs of Cohesity clusters, comma separated (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) one or more clusters to connect to when connecting through Helios or MCM (comma separated)

## Other Parameters

* -unit: (optional) TiB, GiB, MiB or KiB (default is MiB)
* -smtpServer: (optional) SMTP gateway to forward email through
* -smtpPort: (optional) SMTP port to use (default is 25)
* -sendTo: (optional) email addresses to send report to (comma separated)
* -sendFrom: (optional) email address to show in the from field
* -includeArchives: (optional) include storage consumption in archive targets

## Column Descriptions for the Output File (`storageReport_<clusterName>_<datetime>.csv`)

| # | Column Header | Description |
| --- | --- | --- |
| A | **Job/View Name** | Name of the protection job or Cohesity View being reported |
| B | **Tenant** | Tenant/organization name associated with the job or view |
| C | **Environment** | Workload type with the leading `k` stripped (e.g. `VMware`, `SQL`, `Oracle`, `Physical`, `View`) |
| D | **Origination** | Whether the data is `Local` (backed up on this cluster), `Replicated` (received from another cluster), or an archive vault name when `-includeArchives` is used |
| E | **Storage Target** | `Local` for on-cluster storage, or the name of the archival vault target when `-includeArchives` is used |
| F | **\<unit\> Logical** | Logical (pre-dedup/compression) size of the protected data in the chosen unit |
| G | **\<unit\> Ingested** | Amount of data ingested (read from the source) in the chosen unit |
| H | **\<unit\> Consumed** | Actual storage consumed on the cluster (physical footprint) in the chosen unit |
| I | **\<unit\> Written** | Amount of data written to disk after dedup and compression, in the chosen unit |
| J | **\<unit\> Unique** | Unique physical data bytes stored (after global dedup), in the chosen unit |
| K | **Dedup Ratio** | Deduplication ratio — Ingested ÷ Data-after-dedup (higher is better) |
| L | **Compression** | Compression ratio — Data-after-dedup ÷ Data-written (higher is better) |
| M | **Reduction** | Overall data reduction ratio — Ingested ÷ Written (dedup × compression combined) |
| N | **Storage Domain** | Name of the Cohesity Storage Domain (View Box) where the data resides |
| O | **Resiliency Setting** | Resilience/redundancy configuration of the Storage Domain: `RF 1`, `RF 2`, or an erasure coding descriptor such as `EC 4:2` |
