# Customer-Managed — Generic NAS

[← Back to Customer-Managed](index.md)

Total scripts: **18**

## Protection & Recovery (8)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [protectGenericNas.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectGenericNas) | PowerShell | 2025-02-08 | This PowerShell script creates a new protection job for NAS volumes. |
| [protectGenericNas.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectGenericNas) | Python | 2024-12-16 | This script protects generic NAS volumes. |
| [recoverNasList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverNasList) | PowerShell | 2024-11-04 | This powershell script recovers a list of protected NAS shares as Cohesity Views. |
| [recoverNASVolume.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverNASVolume) | PowerShell | 2025-02-09 | This PowerShell script recovers a NAS volume. |
| [recoverNASVolume.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverNASVolume) | Python | 2025-02-09 | This python script recovers a NAS volume. |
| [refreshNASclone.py](https://github.com/cohesity/community-automation-samples/tree/main/python/refreshNASclone) | Python | 2024-11-04 | This python script clones a NAS volume as a Cohesity view. If the view already exists, it will delete it and recreate it from the newer version of the NAS volume backup. |
| [updateGenericNasCredentials.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateGenericNasCredentials) | PowerShell | 2024-11-04 | This powershell script updates credentials for generic NAS (SMB) protection sources. |
| [updateNasCredentials.py](https://github.com/cohesity/community-automation-samples/tree/main/python/updateNasCredentials) | Python | 2024-11-04 | This script updates the username and password in a NAS source registration. |

## Reporting & Analytics (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [nasObjectStats.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/nasObjectStats) | PowerShell | 2024-11-04 | This PowerShell script gathers protected NAS object stats. Output will be written to a CSV file. |

## Views & Storage (9)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [genericNasSources.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/genericNasSources) | PowerShell | 2025-02-11 | This powershell script lists generic NAS sources registered on Cohesity. |
| [globalExcludeNasPath.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/globalExcludeNasPath) | PowerShell | 2024-11-04 | This powershell script adds an excludion path to all generic NAS protection jobs. |
| [globalExcludeNasPath.py](https://github.com/cohesity/community-automation-samples/tree/main/python/globalExcludeNasPath) | Python | 2024-11-04 | This script adds/removes entries to the exclude list for all generic NAS protection groups. |
| [importNasJobs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/importExport) | PowerShell | 2024-11-04 | This script exports various Cohesity objects to json files, to serve as documentation of cluster state and provide the possibility of re-importing some settings and objects for cluster rebuild or disaster recovery use cases. |
| [importNasSources.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/importExport) | PowerShell | 2024-11-04 | This script exports various Cohesity objects to json files, to serve as documentation of cluster state and provide the possibility of re-importing some settings and objects for cluster rebuild or disaster recovery use cases. |
| [nasGetRidHints.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/nasGetRidHints) | PowerShell | 2024-11-04 | This script will gather replication ancestor hints from deleted NAS protection groups. |
| [nasMigrationRidHints.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/nasMigrationRidHints) | PowerShell | 2024-11-04 | This script will gather the incremental replication details for views recovered/migrated from protected NAS volumes/mount points, and generate the needed iris_cli commands to enable incremental first-run replication for the recovered view. |
| [registerGenericNas.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/registerGenericNas) | PowerShell | 2025-02-08 | This powershell script registers one or more generic NAS shares as sources on Cohesity. |
| [registerGenericNas.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerGenericNas) | Python | 2025-02-08 | This script registers generic NAS volumes. |
