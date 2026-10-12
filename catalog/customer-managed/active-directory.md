# Customer-Managed — Active Directory

[← Back to Customer-Managed](README.md)

Total scripts: **8**

## Cluster Configuration (3)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [addActiveDirectory.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/addActiveDirectory) | PowerShell | 2024-11-04 | This script joins a Cohesity cluster to Active Directory. (the main powershell script) |
| [exampleConfig.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/addActiveDirectory) | PowerShell | 2024-11-04 | This script joins a Cohesity cluster to Active Directory. (example configuration file) |
| [joinActiveDirectory.py](https://github.com/cohesity/community-automation-samples/tree/main/python/joinActiveDirectory) | Python | 2024-11-04 | This script will join the Cohesity cluster to an Active Directory domain. |

## Protection & Recovery (3)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [registerADSource.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/registerADSource) | PowerShell | 2024-11-04 | This PowerShell script registers physical servers as Active Directory sources. |
| [restoreADobjects.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreADobjects) | PowerShell | 2024-11-04 | This PowerShell script restores Active Directory objects. |
| [validateADBackup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/validateADBackup) | PowerShell | 2026-09-16 | This PowerShell script validates Active Directory backups. The script will generate an html report and send it to email recipients. The validation process instructs the cluster to mount the latest AD backup to a domain controller and start a new instance (AD recovery instance). A simple AD topology query confirms that the recovery instance is up and operational and the backup is considered valid. |

## User, Access & Security (2)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [onboardADUser.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/onboardADUser) | PowerShell | 2025-08-15 | This powershell script adds or removes Active Directory Users and Groups from Access Management, and can also generate an API key for a user. |
| [onboardADUser.py](https://github.com/cohesity/community-automation-samples/tree/main/python/onboardADUser) | Python | 2024-11-04 | This script creates a Cohesity principal for an Active Directory user. |
