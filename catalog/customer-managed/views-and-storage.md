# Customer-Managed — Views & Storage

[← Back to Customer-Managed](README.md)

Total scripts: **69**

## NFS Views (2)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [createNfsView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/createNfsView) | PowerShell | 2024-11-04 | This powershell script creates an NFS View on Cohesity. |
| [createNFSView.py](https://github.com/cohesity/community-automation-samples/tree/main/python/createNFSView) | Python | 2026-02-11 | This python script creates or updates an NFS View on Cohesity |

## Protection & Recovery (8)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [cloneBackupToView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneBackupToView) | PowerShell | 2026-03-23 | This PowerShell script clones backup files to a Cohesity view. |
| [cloneBackupToView.py](https://github.com/cohesity/community-automation-samples/tree/main/python/cloneBackupToView) | Python | 2024-11-04 | This script clones backup files to an NFS view. |
| [cloneSMBView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneSMBView) | PowerShell | 2024-11-04 | This powershell script clones a protected (active or replicated) SMB view. |
| [cloneView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneView) | PowerShell | 2024-11-04 | This powershell script clones an active or replicated view. |
| [cloneView.py](https://github.com/cohesity/community-automation-samples/tree/main/python/cloneView) | Python | 2024-11-04 | This python script clones a view. |
| [protectView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectView) | PowerShell | 2026-03-25 | This powershell script adds Views to a new or existing protection job. |
| [protectView.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectView) | Python | 2024-11-04 | This python script protects a Cohesity View. |
| [protectViewList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectViewList) | PowerShell | 2024-11-04 | This powershell script creates a protection job for each view listed in a text file. |

## Reporting & Analytics (4)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [smbFileOpens.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/smbFileOpens) | PowerShell | 2025-10-17 | This powershell script lists SMB file opens. |
| [viewFileCounts.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/viewFileCounts) | PowerShell | 2024-11-04 | This powershell script monitors archive tasks. This is especially useful if have just started archiving and may have a back log that you may wish to monitor, or if you are archiving to a seed and ship device (e.g. AWS Snowball). |
| [viewFileCounts.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/viewFileCounts) | Python | 2024-11-04 | This script collects the file and folder count per view. Output is written to a CSV file. |
| [viewGrowth.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/viewGrowth) | PowerShell | 2026-05-22 | This PowerShell script gathers the size of each view from X days util today and calculates the growth. |

## S3 Views (12)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [createS3View.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/createS3View) | PowerShell | 2026-05-13 | This powershell script creates an S3 View on Cohesity. |
| [createS3View.py](https://github.com/cohesity/community-automation-samples/tree/main/python/createS3View) | Python | 2025-02-26 | This python script creates a new S3 View on Cohesity |
| [s3DeleteOldFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/s3test/s3DeleteOldFiles) | Python | 2024-11-04 | This python script deletes files in an S3 view that are older than X time units. |
| [s3DeleteOldFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/s3/python) | Python | 2024-11-04 | These scripts use the boto3 python module. |
| [s3download.py](https://github.com/cohesity/community-automation-samples/tree/main/python/s3test) | Python | 2024-11-04 | These Python scripts demonstrate how to upload and download files to a Cohesity S3 view. |
| [s3download.py](https://github.com/cohesity/community-automation-samples/tree/main/s3/python) | Python | 2024-11-04 | These scripts use the boto3 python module. |
| [s3list-basic.py](https://github.com/cohesity/community-automation-samples/tree/main/s3/python) | Python | 2024-11-04 | These scripts use the boto3 python module. |
| [s3list.py](https://github.com/cohesity/community-automation-samples/tree/main/s3/python) | Python | 2024-11-04 | These scripts use the boto3 python module. |
| [s3list.sh](https://github.com/cohesity/community-automation-samples/tree/main/s3/bash) | Bash/Shell | 2024-11-04 | List Objects in an S3 View using curl |
| [s3upload.py](https://github.com/cohesity/community-automation-samples/tree/main/python/s3test) | Python | 2024-11-04 | These Python scripts demonstrate how to upload and download files to a Cohesity S3 view. |
| [s3upload.py](https://github.com/cohesity/community-automation-samples/tree/main/s3/python) | Python | 2024-11-04 | These scripts use the boto3 python module. |
| [s3uploadFolder.py](https://github.com/cohesity/community-automation-samples/tree/main/s3/python) | Python | 2024-11-04 | These scripts use the boto3 python module. |

## SMB Views (5)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [createSMBView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/createSMBView) | PowerShell | 2024-11-04 | This powershell script creates an SMB View on Cohesity. |
| [createSMBView.py](https://github.com/cohesity/community-automation-samples/tree/main/python/createSMBView) | Python | 2024-11-04 | This python script creates a new SMB View on Cohesity |
| [smbFileClose.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/smbFileClose) | PowerShell | 2025-10-02 | This powershell script closes an open file/folder on a Cohesity view. |
| [smbPermissions.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/smbPermissions) | PowerShell | 2026-02-09 | This powershell script sets SMB share permissions on a view or share. |
| [smbViewList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/smbViewList) | PowerShell | 2025-07-11 | This powershell script lists SMB views, their share and NTFS permissions. Output is written to a CSV file. |

## View DR (13)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [cleanupJobs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewDR-MT) | PowerShell | 2024-11-04 | These powershell scripts recover replicated views at the DR site, in a manner that works with Multi-tenancy. |
| [cleanupJobs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewDR) | PowerShell | 2024-11-04 | These powershell scripts recover replicated views at the DR site. Note that these scripts require the View DR features of Cohesity 6.6 or later |
| [cleanupUnmergedViews.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewDR) | PowerShell | 2024-11-04 | These powershell scripts recover replicated views at the DR site. Note that these scripts require the View DR features of Cohesity 6.6 or later |
| [cnameFailover.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewDR) | PowerShell | 2024-11-04 | These powershell scripts recover replicated views at the DR site. Note that these scripts require the View DR features of Cohesity 6.6 or later |
| [dfsFailover.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewDR) | PowerShell | 2024-11-04 | These powershell scripts recover replicated views at the DR site. Note that these scripts require the View DR features of Cohesity 6.6 or later |
| [failoverMonitor.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewDR) | PowerShell | 2025-05-27 | These powershell scripts recover replicated views at the DR site. Note that these scripts require the View DR features of Cohesity 6.6 or later |
| [viewDR.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewDR) | PowerShell | 2024-11-04 | These powershell scripts recover replicated views at the DR site. Note that these scripts require the View DR features of Cohesity 6.6 or later |
| [viewDR.py](https://github.com/cohesity/community-automation-samples/tree/main/python/viewDR) | Python | 2025-02-03 | This python script performs a failover of Cohesity views. |
| [viewDRclone.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewDR-MT) | PowerShell | 2024-11-04 | These powershell scripts recover replicated views at the DR site, in a manner that works with Multi-tenancy. |
| [viewDRcollect.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewDR-MT) | PowerShell | 2024-11-04 | These powershell scripts recover replicated views at the DR site, in a manner that works with Multi-tenancy. |
| [viewDRdelete.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewDR-MT) | PowerShell | 2024-11-04 | These powershell scripts recover replicated views at the DR site, in a manner that works with Multi-tenancy. |
| [viewDRtest-clone.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/ViewDRtest) | PowerShell | 2024-11-04 | These powershell scripts clone replicated Views for a DR test. |
| [viewDRtest-delete.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/ViewDRtest) | PowerShell | 2024-11-04 | These powershell scripts clone replicated Views for a DR test. |

## Views & Storage (25)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [addGlobalWhiteListEntries.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/addGlobalWhiteListEntries) | PowerShell | 2024-11-04 | This powershell script adds whitelist entries to a Cohesity view. |
| [addNTFSPermissions.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/addNTFSPermissions) | PowerShell | 2024-11-04 | This powershell script adds NTFS permissions to a view. Note that new NTFS permissions will not propagate to existing files and folders and will only be present at the root of the view and propagate to new files and folders created after the new permissions have been added. |
| [createViewAlias.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/createViewAlias) | PowerShell | 2024-11-04 | This powershell script creates a view alias (additional share) in a Cohesity View. |
| [createViewAlias.py](https://github.com/cohesity/community-automation-samples/tree/main/python/createViewAlias) | Python | 2024-11-04 | This python script creates a view alias (additional share) in a Cohesity View. |
| [createZDLRAView.py](https://github.com/cohesity/community-automation-samples/tree/main/python/createZDLRAView) | Python | 2024-11-04 | This python script creates or updates a ZDLRA View on Cohesity |
| [deleteView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deleteView) | PowerShell | 2024-11-04 | This PowerShell script deletes a Cohesity view. |
| [deleteView.py](https://github.com/cohesity/community-automation-samples/tree/main/python/deleteView) | Python | 2024-11-04 | This python script deletes a view. |
| [directoryQuota.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/directoryQuota) | PowerShell | 2024-11-04 | This powershell script sets a quota on a directory within a Cohesity view. |
| [exportConfiguration.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/importExport) | PowerShell | 2024-11-04 | This script exports various Cohesity objects to json files, to serve as documentation of cluster state and provide the possibility of re-importing some settings and objects for cluster rebuild or disaster recovery use cases. |
| [exportConfigurationV2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/importExport) | PowerShell | 2024-11-04 | This script exports various Cohesity objects to json files, to serve as documentation of cluster state and provide the possibility of re-importing some settings and objects for cluster rebuild or disaster recovery use cases. |
| [exportedViews.py](https://github.com/cohesity/community-automation-samples/tree/main/python/exportedViews) | Python | 2024-11-04 | This python script list views and to what IP addresses they are exported. |
| [globalWhiteList.py](https://github.com/cohesity/community-automation-samples/tree/main/python/globalWhiteList) | Python | 2024-11-04 | This python script adds, removes and lists global white list entries |
| [importStorageDomains.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/importExport) | PowerShell | 2024-11-04 | This script exports various Cohesity objects to json files, to serve as documentation of cluster state and provide the possibility of re-importing some settings and objects for cluster rebuild or disaster recovery use cases. |
| [listViews.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/listViews) | PowerShell | 2024-11-04 | This PowerShell script lists Cohesity views. |
| [listViews.py](https://github.com/cohesity/community-automation-samples/tree/main/python/listViews) | Python | 2025-02-24 | This python script lists views on Cohesity |
| [migrateDirectoryQuotas.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateDirectoryQuotas) | PowerShell | 2025-08-14 | This powershell script copies directory quotas from one view to another. |
| [overwriteView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/overwriteView) | PowerShell | 2026-02-10 | This powershell script overwrites a view from another view. |
| [setUserQuota.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/setUserQuota) | PowerShell | 2024-11-04 | This powershell script sets custom user quotas on a Cohesity View. |
| [shareList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/shareList) | PowerShell | 2025-07-23 | This PowerShell script lists Views and Shares. |
| [viewAddWhitelistEntries.py](https://github.com/cohesity/community-automation-samples/tree/main/python/viewAddWhitelistEntries) | Python | 2026-09-09 | This python script adds subnet whitelist entries (NFS/SMB/S3 access) to one or more existing Cohesity views. |
| [viewAddWhiteListEntriesV2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewAddWhiteListEntriesV2) | PowerShell | 2026-09-09 | This powershell script adds whitelist entries to a Cohesity view, using the V2 Cohesity API. |
| [viewConnections.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewConnections) | PowerShell | 2024-11-04 | This PowerShell script lists view client connections. |
| [viewConnections.py](https://github.com/cohesity/community-automation-samples/tree/main/python/viewConnections) | Python | 2024-11-04 | This python script lists view client connections. Output will be saved to a CSV file. |
| [viewFileList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewFileList) | PowerShell | 2024-11-04 | This powershell script enumerates the list of files and folders in a view. |
| [viewList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/viewList) | PowerShell | 2026-06-08 | This powershell script lists Cohesity views. |
