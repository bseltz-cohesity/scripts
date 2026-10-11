# Customer-Managed — General / Multi-Platform

[← Back to Customer-Managed](index.md)

Total scripts: **35**

## Other / Utility (5)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [addCustomHostMapping.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/addCustomHostMapping) | PowerShell | 2024-11-04 | This script adds a customer host mapping to Cohesity. |
| [advDiagEnum.py](https://github.com/cohesity/community-automation-samples/tree/main/python/advDiagEnum) | Python | 2026-07-10 | This script enumerates advanced diagnostics schemas and metrics and outputs to a CSV file. |
| [pulseLogs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/pulseLogs) | PowerShell | 2025-09-23 | This script gathers pulse logs and writes them to text files. |
| [sslFix.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/sslFix) | PowerShell | 2024-11-04 | This repository contains many examples of how to automate Cohesity using PowerShell. Common to each example is a function library that makes it easy to authenticate and make api calls. Below are details of this library. |
| [updateJobDescriptionDate.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateJobDescriptionDate) | PowerShell | 2024-11-04 | This powershell script adds a date suffix to all job descriptions. |

## Protection & Recovery (27)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [downloadLatestWarnings.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/downloadLatestWarnings) | PowerShell | 2024-11-04 | This powershell script downloads the warning messages (if any) from each object of the last run of a protection group. Downloaded files will be named groupname-objectname-warnings.txt. |
| [downloadLatestWarnings.py](https://github.com/cohesity/community-automation-samples/tree/main/python/downloadLatestWarnings) | Python | 2025-07-17 | This python script script downloads the warning messages (if any) from each object of the last run of a protection group. Downloaded files will be named groupname-objectname-warnings.csv |
| [fixRedundantProtection.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/fixRedundantProtection) | PowerShell | 2025-01-07 | This script inspects the list of objects protected by a job, and removes them from all other jobs, thus eliminating redundant protection. |
| [freeze.sh](https://github.com/cohesity/community-automation-samples/tree/main/python/freezeThawRemote) | Bash/Shell | 2024-11-04 | This example shows how to use a remote Python host to enable API driven triggering of freeze/thaw scripts on hosts (like AIX) where a viable scripting language may not be available. (contains host freeze commands, placed on the AIX host) |
| [jobDumper.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/jobDumper) | PowerShell | 2024-11-04 | This PowerShell script dumps the specified protection groups to JSON for analysis. |
| [jobDumper.py](https://github.com/cohesity/community-automation-samples/tree/main/python/jobDumper) | Python | 2024-11-04 | This script script dumps the specified protection groups to JSON for analysis. |
| [jobList.py](https://github.com/cohesity/community-automation-samples/tree/main/python/jobList) | Python | 2026-08-11 | This script lists protection jobs. |
| [jobRunning.py](https://github.com/cohesity/community-automation-samples/tree/main/python/jobRunning) | Python | 2025-07-22 | This python script determines if a protection job is running or not. If it is running, it will exit with exit code 1, otherwise it will exit with exit code 0. |
| [linkSharesMaster.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/linkShares) | PowerShell | 2024-11-04 | This powershell script creates symbolic links to file shares on a remote computer and includes them in a physical protection job. (the main powershell script (Master role)) |
| [linkSharesProxy.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/linkShares) | PowerShell | 2024-11-04 | This powershell script creates symbolic links to file shares on a remote computer and includes them in a physical protection job. (the main powershell script (Proxy role)) |
| [marketplaceApps.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/marketplaceApps) | PowerShell | 2024-11-04 | This powershell script can display, pause, resume and terminate marketplace app instances. |
| [myBackupStatus.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/myBackupStatus) | PowerShell | 2024-11-04 | This PowerShell script detects if the specified object is currently being backed up. |
| [objectProtectionDetails.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/objectProtectionDetails) | PowerShell | 2024-11-04 | This script shows the protection details for an object. |
| [objectProtectionStatus.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/objectProtectionStatus) | PowerShell | 2025-10-04 | This script shows the protection status for an object. |
| [objectProtectionStatus.py](https://github.com/cohesity/community-automation-samples/tree/main/python/objectProtectionStatus) | Python | 2025-10-02 | This script shows the protection status for an object. |
| [refreshSource.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/refreshSource) | PowerShell | 2024-11-04 | This script demonstrates how to perform a refresh operation on a protection source. The prime example of where this is useful is if a new virtual machine is created on VMware (or other hypervisor) and you want Cohesity to recognize the new VM. Refresh is automatic on a schedule, but a manual refresh can be executed to speed up the process. |
| [refreshSource.py](https://github.com/cohesity/community-automation-samples/tree/main/python/refreshSource) | Python | 2025-05-06 | This script refreshes a protection source. |
| [renameJobs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/renameJobs) | Python | 2024-11-04 | This Python script renames one or more protection jobs. |
| [thaw.sh](https://github.com/cohesity/community-automation-samples/tree/main/python/freezeThawRemote) | Bash/Shell | 2024-11-04 | This example shows how to use a remote Python host to enable API driven triggering of freeze/thaw scripts on hosts (like AIX) where a viable scripting language may not be available. (contains host freeze commands, placed on the AIX host) |
| [touchJob.py](https://github.com/cohesity/community-automation-samples/tree/main/python/touchJob) | Python | 2024-11-04 | This script simply gets and puts a protection job, the purpose being to change the ownership of the job. |
| [unprotectMissingObjects.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/unprotectMissingObjects) | PowerShell | 2024-11-04 | This powershell script removes missing objects from protection groups. |
| [unprotectObjects.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/unprotectObjects) | PowerShell | 2024-11-04 | This powershell script removes objects from protection groups. |
| [unregisterProtectionSource.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/unregisterProtectionSource) | PowerShell | 2024-11-04 | This powershell script unregisters a protection source. |
| [unregisterSource.py](https://github.com/cohesity/community-automation-samples/tree/main/python/unregisterSource) | Python | 2025-02-26 | This script unregisters protection sources. |
| [updateJob.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateJob) | PowerShell | 2026-06-30 | This script modifies various protection job properties including policy, startTime, timeZone, incremental and full SLAs. |
| [updateJobDescriptions.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateJobDescriptions) | PowerShell | 2024-11-04 | This powershell script updates protection group descriptions from a CSV file. |
| [updateJobSettings.py](https://github.com/cohesity/community-automation-samples/tree/main/python/updateJobSettings) | Python | 2024-11-04 | This script updates various common protection group settings, including: |

## Reporting & Analytics (3)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [enableFilerAuditing.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/enableFilerAuditing) | PowerShell | 2024-11-04 | This powershell script enables/disables audit logging on views and shares. |
| [logicalSizeGrowth.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/logicalSizeGrowth) | PowerShell | 2024-11-04 | This PowerShell script displays the logical size of a protected view over time. |
| [snowReportStrikes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/snowReportStrikes) | PowerShell | 2024-11-04 | This PowerShell script creates ServiceNow incidents for protection jobs that have failed X times in a row, |
