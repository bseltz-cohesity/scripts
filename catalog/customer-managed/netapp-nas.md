# Customer-Managed — NetApp (NAS)

[← Back to Customer-Managed](index.md)

Total scripts: **11**

## NFS Views (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [netapp7ImportNFS.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/netapp7migration) | PowerShell | 2024-11-04 | This script migrates SMB shares from NetApp. The script assumes that the NetApp volumes have been protected by Cohesity. The script will restore the volumes as Cohesity views, create nested shares and apply share permissions. The share information is exported from NetApp using the NetApp PowerShell Toolkit. (import netapp 7-mode NFS exports) |

## Protection & Recovery (6)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [excludeNetAppVolumes.py](https://github.com/cohesity/community-automation-samples/tree/main/python/excludeNetAppVolumes) | Python | 2024-11-04 | This python script excludes volumes from protection groups that autoprotect NetApp clusters/SVMs, if the volume name matches one of a list of search strings. |
| [netappImportShares.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/netappImportShares) | PowerShell | 2026-01-13 | This script migrates SMB shares from NetApp. The script assumes that the NetApp volumes have been protected by Cohesity. The script will restore the volumes as Cohesity views, create nested shares and apply share permissions. The share information is exported from NetApp using the NetApp PowerShell Toolkit. |
| [netappPathFilters.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/netappPathFilters) | PowerShell | 2024-11-04 | This PowerShell script adds inclusion and exclusion paths to a NetApp protection job. |
| [netappPortTest.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/netappPortTest) | PowerShell | 2024-11-04 | This powershell script tests that the ports required for Cohesity to protect a Netapp are accessible. Any blocked ports will be highlighted in yellow. |
| [protectNetapp.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectNetapp) | PowerShell | 2024-11-04 | This PowerShell script creates a new protection job for Netapp volumes. |
| [protectNetapp.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectNetapp) | Python | 2024-11-04 | This script adds Netapp Volumes to a protection job. |

## Reporting & Analytics (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [netappInventory.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/netappInventory) | PowerShell | 2024-11-04 | This PowerShell script reports on resgistered Netapp protection sources and the protection status of the volumes and outputs to a CSV file. |

## SMB Views (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [netapp7ImportSMB.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/netapp7migration) | PowerShell | 2024-11-04 | This script migrates SMB shares from NetApp. The script assumes that the NetApp volumes have been protected by Cohesity. The script will restore the volumes as Cohesity views, create nested shares and apply share permissions. The share information is exported from NetApp using the NetApp PowerShell Toolkit. (import netapp 7-mode SMB shares) |

## User, Access & Security (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [netappCreateCohesityUser.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/netappCreateCohesityUser) | PowerShell | 2024-11-04 | This powershell script creates a NetApp user and role with the required permissions to register a NetApp protection source in Cohesity. |

## Views & Storage (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [netapp7Export.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/netapp7migration) | PowerShell | 2024-11-04 | This script migrates SMB shares from NetApp. The script assumes that the NetApp volumes have been protected by Cohesity. The script will restore the volumes as Cohesity views, create nested shares and apply share permissions. The share information is exported from NetApp using the NetApp PowerShell Toolkit. (export netapp 7-mode configuration details) |
