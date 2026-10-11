# Helios-Only — Helios Reporting

[← Back to Helios-Only](README.md)

Total scripts: **12**

## Monitoring & Alerting (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [heliosMonitor.py](https://github.com/cohesity/community-automation-samples/tree/main/python/heliosMonitor) | Python | 2026-03-01 | This python script monitors the startup of Helios self-managed. I will attempt to authenticate to Helios self-managed until it is successful. |

## Other / Utility (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [heliosObjectUuid.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/heliosObjectUuid) | PowerShell | 2025-11-03 | This PowerShell script searches for an object by name and displays its global Uuid. |

## Reporting & Analytics (10)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [dataClasificationScanReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-other/powershell/dataClasificationScanReport) | PowerShell | 2026-07-10 | This script gathers Data Classification (DLP) scan results, drilling down from scans, to scan runs, to the scanned objects within each run, to the individual sensitive files found, and outputs the file-level detail (including which pattern was matched and its sensitivity) to a CSV file. |
| [heliosAnomalyReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-other/powershell/heliosAnomalyReport) | PowerShell | 2024-11-04 | This script gathers ransomware anomalies and outputs to a CSV file. |
| [heliosAuditLogs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-other/powershell/heliosAuditLogs) | PowerShell | 2026-08-10 | This script gathers audit logs from Helios and saves them to a CSV file |
| [heliosConsumerTrendReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/powershell/heliosConsumerTrendReport) | PowerShell | 2026-09-30 | This PowerShell script pulls the Helios **Storage Consumption by Views** and **Storage Consumption by Protection Groups** reports for a run of consecutive calendar months, and pivots the results into a single monthly trend report: one row per view / protection group, with columns for `dataIngestedRetained` and `scRetained` for each month, plus scRetained growth columns. It can also write an HTML report with a chart of scRetained over time per entity. |
| [heliosCSVReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/powershell/heliosCSVReport) | PowerShell | 2026-09-28 | This PowerShell script creates helios reports and outputs CSV format. |
| [heliosDashboardExporter.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/grafana/JSON-API/heliosDashboard) | Python | 2026-08-27 | This Grafana dashboard displays a Helios cluster health and status table. It shows, for every cluster connected to Helios: connection/health state, software version and patch level, upgrade status, node count, capacity usage, and the most recent open critical or warning alert. |
| [heliosReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-reporting/python/heliosReport) | Python | 2026-09-28 | This Python script creates helios reports and outputs to HTML, CSV and TSV files. |
| [heliosSMBackups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-other/powershell/heliosSMBackups) | PowerShell | 2026-03-16 | This script lists Helios Self-Managed backups and outputs to a CSV file. |
| [heliosSMBackups.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/helios-other/python/heliosSMBackups) | Python | 2026-03-16 | This script lists Helios Self-Managed backups and outputs to a CSV file. |
| [powerBI-helios-detectedAnomalies.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/powerBI/python/powerBI-helios-detectedAnomalies) | Python | 2024-11-04 | This python script imports detected ransomware anomalies from Helios into Power BI |
