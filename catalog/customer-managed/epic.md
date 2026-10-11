# Customer-Managed — Epic

[← Back to Customer-Managed](README.md)

Total scripts: **11**

## Cluster Configuration (2)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [epicGflagRecommendations.ps1](https://github.com/cohesity/community-automation-samples/tree/main/epic/powershell/epicGflagRecommendations) | PowerShell | 2026-10-05 | This PowerShell script calculates recommended Cohesity cluster and agent gflag settings for tuning EPIC Cache/IRIS (operational database) backup performance on physical Linux or AIX mount hosts -- replacing the `Auto tuning Gflags for epic backups for linux_AIX physical.xlsx` spreadsheet previously used for this. Given a handful of inputs about the cluster and mount host, it prints the recommended settings to the screen and writes them -- along with ready-to-paste commands and instructions to apply them -- to a text file. |
| [epicGflagRecommendations.sh](https://github.com/cohesity/community-automation-samples/tree/main/epic/bash/epicGflagRecommendations) | Bash/Shell | 2026-10-05 | This bash script calculates recommended Cohesity cluster and agent gflag settings for tuning EPIC Cache/IRIS (operational database) backup performance on physical Linux or AIX mount hosts. Given a handful of inputs about the cluster and mount host, it prints the recommended settings to the screen and writes them - along with ready-to-paste commands and instructions to apply them - to a text file. |

## Protection & Recovery (9)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [epic_azure_freeze_thaw.sh](https://github.com/cohesity/community-automation-samples/tree/main/epic/remoteAdapter/epic_azure_freeze_thaw) | Bash/Shell | 2026-10-05 | This bash script can be used to freeze Epic Iris DB running in an Azure VM, snapshot the data disks, mount the snapshot disks to a mount host VM, then start a protection group to backup the mount host. |
| [epic_pure_ppg_freeze.sh](https://github.com/cohesity/community-automation-samples/tree/main/epic/bash/epic_pure_ppg_freeze_thaw) | Bash/Shell | 2026-10-05 | These bash scripta can be used the pre-script and post-snapshot-script in a Cohesity Pure FlashArray protection group backup to freeze/thaw the EPIC operational database. |
| [epic_pure_ppg_thaw.sh](https://github.com/cohesity/community-automation-samples/tree/main/epic/bash/epic_pure_ppg_freeze_thaw) | Bash/Shell | 2026-10-05 | These bash scripta can be used the pre-script and post-snapshot-script in a Cohesity Pure FlashArray protection group backup to freeze/thaw the EPIC operational database. |
| [epic_pure_snapper.sh](https://github.com/cohesity/community-automation-samples/tree/main/epic/bash/epic_pure_snapper) | Bash/Shell | 2026-10-05 | This bash script freezes an EPIC database, snapshots the related Pure volumes, and thaws the database. This script is not for use with Cohesity backups but is just a tool to make a clean snapshot of Epic. |
| [epic_vm_freeze_thaw.sh](https://github.com/cohesity/community-automation-samples/tree/main/epic/bash/epic_vm_freeze_thaw) | Bash/Shell | 2026-10-05 | This bash script can be used as a VMTools Freeze/Thaw Script for a Cohesity VMware backup to freeze and thaw an EPIC database. |
| [epicThroughputCalculator.ps1](https://github.com/cohesity/community-automation-samples/tree/main/epic/powershell/epicThroughputCalculator) | PowerShell | 2026-10-05 | This PowerShell script estimates Full, Incremental, and Pure Incremental backup durations (and the resulting restore duration) for an EPIC Cache/IRIS (operational database) mount host, and identifies the throughput bottleneck for each. Given the mount host's database size, FC and NIC connectivity, and the Cohesity cluster's node count and ingest speed, it prints the estimated durations and bottlenecks to the screen. |
| [postscript.sh](https://github.com/cohesity/community-automation-samples/tree/main/epic/remoteAdapter/epic_azure_freeze_thaw) | Bash/Shell | 2026-10-05 | This bash script can be used to freeze Epic Iris DB running in an Azure VM, snapshot the data disks, mount the snapshot disks to a mount host VM, then start a protection group to backup the mount host. |
| [prescript.sh](https://github.com/cohesity/community-automation-samples/tree/main/epic/remoteAdapter/epic_azure_freeze_thaw) | Bash/Shell | 2026-10-05 | This bash script can be used to freeze Epic Iris DB running in an Azure VM, snapshot the data disks, mount the snapshot disks to a mount host VM, then start a protection group to backup the mount host. |
| [vm_freeze_thaw.sh](https://github.com/cohesity/community-automation-samples/tree/main/epic/remoteAdapter/vm_freeze_thaw) | Bash/Shell | 2026-10-05 | This bash script can be used as a pre-script in a remote adapter job to freeze an application, run a VM backup job and thaw the application. The script will call the included commands during the process to monitor and run the VM job. |
