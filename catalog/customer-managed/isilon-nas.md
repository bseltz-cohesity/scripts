# Customer-Managed — Isilon (NAS)

[← Back to Customer-Managed](README.md)

Total scripts: **9**

## Migration (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [migrateIsilonShares.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/migrateIsilonShares) | PowerShell | 2024-11-04 | This script takes SMB share information from isilon, and for each share, identifies the matching subdirectory on the specified Cohesity view, and migrates share permissions and child shares. Note that share-level SMB permissions require Cohesity version 6.4 or later. |

## Other / Utility (2)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [isilonCFTtest.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/isilonCFTtest) | PowerShell | 2024-11-04 | This powershell script tests Isilon Change File Tracking performance. |
| [isilonCTFtest.py](https://github.com/cohesity/community-automation-samples/tree/main/python/isilonCFTtest) | Python | 2024-11-04 | This python script tests Isilon Change File Tracking performance. |

## Protection & Recovery (5)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [isilon-api.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/isilon-api) | PowerShell | 2024-11-04 | This is a function library for Isilon API that uses session cookie authentication with CSRF protection. This is not for the Cohesity API but is useful when connecting to Isilon API. |
| [protectIsilon.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectIsilon) | PowerShell | 2026-10-21 | This PowerShell script creates a new protection job for Isilon volumes. |
| [protectIsilon.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectIsilon) | Python | 2026-10-21 | This script adds Isilon Volumes to a protection job. |
| [registerIsilon.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/registerIsilon) | PowerShell | 2024-11-04 | This powershell script registers an Isilon protection source. |
| [registerIsilon.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerIsilon) | Python | 2024-11-04 | This script registers an Isilon as a protection source. |

## User, Access & Security (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [isilonCreateCohesityUser.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/isilonCreateCohesityUser) | PowerShell | 2024-11-04 | This powershell script creates an Isilon user and role with the required permissions to register an Isilon protection source in Cohesity. |
