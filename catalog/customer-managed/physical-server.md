# Customer-Managed — Physical Server

[← Back to Customer-Managed](index.md)

Total scripts: **31**

## Migration (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [migrateWindowsShares.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateWindowsShares) | PowerShell | 2025-03-29 | This script enumerates smbShares on the local Windows server and for each share requested, identifies the matching view on Cohesity, and migrates share permissions and child shares. |

## Protection & Recovery (26)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [addGlobalExcludePaths.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/addGlobalExcludePaths) | PowerShell | 2024-11-04 | This script adds global exclude paths to a file-based protection group. |
| [addGlobalExcludePaths.py](https://github.com/cohesity/community-automation-samples/tree/main/python/addGlobalExcludePaths) | Python | 2024-11-04 | This script adds global exclude paths to file-based physical protection groups. |
| [fileBasedJobLeastObjects.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/fileBasedJobLeastObjects) | PowerShell | 2024-11-04 | This powershell script finds the file-based physical protection group using the least number of protected objects. |
| [fileBasedJobLeastObjects.py](https://github.com/cohesity/community-automation-samples/tree/main/python/fileBasedJobLeastObjects) | Python | 2024-11-04 | This python script finds the file-based physical protection group using the least number of protected objects. |
| [globalExcludePaths.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/globalExcludePaths) | PowerShell | 2024-11-04 | This PowerShell script adds global exclude paths to file-based protection groups. |
| [globalExcludePaths.py](https://github.com/cohesity/community-automation-samples/tree/main/python/globalExcludePaths) | Python | 2024-11-04 | This script adds physical linux servers to a file-based protection job. |
| [physicalProtectedBy.py](https://github.com/cohesity/community-automation-samples/tree/main/python/physicalProtectedBy) | Python | 2024-11-04 | This script reports what protection group is protecting a server, if any. |
| [postscript.cmd](https://github.com/cohesity/community-automation-samples/tree/main/windows/vssSnapshot) | Windows Command Script | 2024-11-04 | These Windows scripts can be used as a Pre and Post Scripts in a Cohesity Physical File-based backup of a Windows host to create VSS snapshots of the volumes prior to the backup starting, and deleting the snapshots when the backup is complete. |
| [postscript.ps1](https://github.com/cohesity/community-automation-samples/tree/main/windows/vssSnapshot) | PowerShell | 2024-11-04 | These Windows scripts can be used as a Pre and Post Scripts in a Cohesity Physical File-based backup of a Windows host to create VSS snapshots of the volumes prior to the backup starting, and deleting the snapshots when the backup is complete. |
| [postscript.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/lv_snapper) | Bash/Shell | 2024-11-04 | These bash scripts can be used as a Pre and Post Scripts in a Cohesity Physical File-based backup of a Linux host to snapshot an LVM logical volume prior to the backup starting, and deleting the snapshot when the backup is complete. |
| [prescript.cmd](https://github.com/cohesity/community-automation-samples/tree/main/windows/vssSnapshot) | Windows Command Script | 2024-11-04 | These Windows scripts can be used as a Pre and Post Scripts in a Cohesity Physical File-based backup of a Windows host to create VSS snapshots of the volumes prior to the backup starting, and deleting the snapshots when the backup is complete. |
| [prescript.ps1](https://github.com/cohesity/community-automation-samples/tree/main/windows/vssSnapshot) | PowerShell | 2024-11-04 | These Windows scripts can be used as a Pre and Post Scripts in a Cohesity Physical File-based backup of a Windows host to create VSS snapshots of the volumes prior to the backup starting, and deleting the snapshots when the backup is complete. |
| [prescript.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/lv_snapper) | Bash/Shell | 2024-11-04 | These bash scripts can be used as a Pre and Post Scripts in a Cohesity Physical File-based backup of a Linux host to snapshot an LVM logical volume prior to the backup starting, and deleting the snapshot when the backup is complete. |
| [protectLinux.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectLinux) | PowerShell | 2025-08-22 | This PowerShell script adds physical Linux servers to a file-based protection job. |
| [protectLinux.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectLinux) | Python | 2025-08-22 | This script adds physical linux servers to a file-based protection job. |
| [protectLinuxVolumes.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectLinuxVolumes) | Python | 2025-08-31 | This script adds physical linux servers to a block-based protection job. |
| [protectWindows.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectWindows) | PowerShell | 2025-02-21 | This PowerShell script adds physical Windows servers to a file-based protection job. |
| [protectWindows.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectWindows) | Python | 2024-11-04 | This script adds physical Windows servers to a file-based protection job. |
| [protectWindowsVolumes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectWindowsVolumes) | PowerShell | 2024-11-04 | This PowerShell script adds physical Windows servers to a volume-based protection job. |
| [recoverWindowsShareAsView.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverWindowsShareAsView) | PowerShell | 2025-04-02 | This PowerShell script recovers a Windows Share (Generic NAS Backup) as a Cohesity View. It can also migrate the SMB Share permissions and child shares from the Windows host. |
| [registerPhysical.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/registerPhysical) | PowerShell | 2024-11-04 | This powershell script registers new physical host(s) as a Cohesity protection source. |
| [registerPhysical.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerPhysical) | Python | 2024-11-04 | This script registers physical protection sources. |
| [unprotectPhysicalServer.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/unprotectPhysicalServer) | PowerShell | 2024-11-04 | This powershell script removes a server from physical protection jobs. |
| [unprotectPhysicalServer.py](https://github.com/cohesity/community-automation-samples/tree/main/python/unprotectPhysicalServer) | Python | 2025-05-19 | This script removes physical servers from file-based or block-based protection groups. |
| [updateWindowsAllDrives.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateWindowsAllDrives) | PowerShell | 2024-11-04 | This PowerShell script updates physical file-based Windows protection to protect all local drives, if only the C drive is protected (the default). |
| [updateWindowsAllDrives.py](https://github.com/cohesity/community-automation-samples/tree/main/python/updateWindowsAllDrives) | Python | 2024-11-04 | This python script updates physical file-based Windows protection to protect all local drives, if only the C drive is protected (the default). |

## Reporting & Analytics (4)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [directiveBackupHistoryReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/directiveBackupHistoryReport) | Python | 2024-11-04 | This Python script reports directive files used for physical server file-based backups over the past X days. |
| [physicalBackupPathsHistoryReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/physicalBackupPathsHistoryReport) | Python | 2025-11-14 | This Python script reports backed up paths for physical server file-based backups over the past X days. Note that the report can only include backups that are still in retention, and can only report backups that occured later than the last modified date of the protection group. |
| [physicalBackupPathsReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/physicalBackupPathsReport) | Python | 2024-11-04 | This Python script reports include and exclude paths for physical server file-based backups. |
| [protectedFilePathReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/protectedFilePathReport) | PowerShell | 2025-04-10 | This PowerShell script generates a report of included and excluded file paths per host in physical file-based protection groups. The script will generate an html report and also generate a CSV file. |
