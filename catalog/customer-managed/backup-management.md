# Customer-Managed — Backup Management

[← Back to Customer-Managed](README.md)

Total scripts: **19**

## Other / Utility (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [restartFailedJobs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restartFailedJobs) | Python | 2024-11-04 | This script restarts jobs if the last run was not successful. Output is logged to a text file. |

## Protection & Recovery (18)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [backupLogs.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/old/backupLogs) | Bash/Shell | 2024-11-04 | This bash script performs a runNow on a protection job, specifying the log backup type. |
| [backupNow.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backupNow) | PowerShell | 2026-09-23 | This PowerShell script performs a runNow on a protection job and optionally replicates and/or archives the backup to the specified targets. Also, the script will optionally enable a disabled job to run it, and disable it when done. The script will wait for the job to fimish and report the end status of the job. |
| [backupNow.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backupNow) | Python | 2026-09-23 | This Python script performs a runNow on a protection job and optionally replicates and/or archives the backup to the specified targets. Also, the script will optionally enable a disabled job to run it, and disable it when done. The script will wait for the job to finish and report the end status of the job. |
| [backupNow.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/backupNow) | Bash/Shell | 2024-11-04 | This bash script runs a protection job. It will use the policy settings to include replication and archive copies. Note that the base retention is used (extended retentions are not applied). For physical server backups, you can optionally specify one server to backup (otherwise all servers are backed up). The script supports API key authentication only. |
| [backupNowAndCopy.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/old/backupNowAndCopy) | Bash/Shell | 2024-11-04 | This bash script performs a runNow on a protection job including replication and archiving to an external target. All retentions and targets are explicitly defined in the settings section at the top of the script. |
| [backupNowAPIKey.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/old/backupNowAPIKey) | Bash/Shell | 2024-11-04 | This bash script performs a runNow on a protection job including replication and archiving to an external target. All retentions and targets are explicitly defined in the settings section at the top of the script. |
| [backupNowDisabledJob.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/old/backupNowDisabledJob) | Bash/Shell | 2024-11-04 | This bash script unpauses a protection job, performs a runNow, waits for completion, re-pauses the job, and reports completion status. |
| [backupNowFromPolicy.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/old/backupNowFromPolicy) | Bash/Shell | 2024-11-04 | This bash script performs a runNow on a protection job including replication and archiving to an external target. All retentions and targets are queried from the policy applied to the protection job. |
| [backupNowOneObject.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/old/backupNow-simple) | Bash/Shell | 2024-11-04 | This bash script performs a run now on a protection job, selecting one object. This script is ultra simplified to eliminate the dependency on jq. A more advanced version is here: <https://github.com/cohesity/community-automation-samples/tree/main/bash/backupNow> |
| [cancelRunningJob.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cancelRunningJob) | PowerShell | 2024-11-04 | This PowerShell script will cancel a running protection job. |
| [cancelRunningJobs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/cancelRunningJobs) | Python | 2024-11-04 | This script cancels running protection jobs |
| [cancelRunningObject.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cancelRunningObject) | PowerShell | 2024-11-04 | This PowerShell script cancels the backup for a single object in a protection run. |
| [cancelRunningObject.py](https://github.com/cohesity/community-automation-samples/tree/main/python/cancelRunningObject) | Python | 2024-11-04 | This python script cancels the backup for a single object in a protection run. |
| [pauseProtectionActivity.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pauseProtectionActivity) | Python | 2024-11-04 | This Python script pauses (or resumes) protection groups, replication, archival, indexing and garbage collection activity with the goal of optimizing performance for restore operations. |
| [pauseResumeJobs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/pauseResumeJobs) | PowerShell | 2024-11-04 | This PowerShell script can pause, resume or show the state of a protection job. |
| [pauseResumeJobs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/pauseResumeJobs) | Python | 2025-06-26 | This Python script pauses or resumes future runs of one or more protection jobs. |
| [restartFailedJobs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restartFailedJobs) | PowerShell | 2026-07-21 | This PowerShell script finds failed protection groups and restarts them by running a new incremental backup that includes only the failed objects. |
| [waitforsnaps.sh](https://github.com/cohesity/community-automation-samples/tree/main/python/freezeThawRemote) | Bash/Shell | 2024-11-04 | This example shows how to use a remote Python host to enable API driven triggering of freeze/thaw scripts on hosts (like AIX) where a viable scripting language may not be available. (calls remote python script) |
