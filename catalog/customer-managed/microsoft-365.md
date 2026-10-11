# Customer-Managed — Microsoft 365

[← Back to Customer-Managed](index.md)

Total scripts: **24**

## Protection & Recovery (24)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [autoprotectM365Mailboxes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/autoprotectM365Mailboxes) | PowerShell | 2026-09-21 | This PowerShell script adds unprotected M365 mailboxes to a protection group. New protection groups will be created automatically so existing protection groups will be not grow beyond the number of mailboxes specified by the -maxObjectsPerJob setting. |
| [autoprotectO365.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/autoprotectO365) | PowerShell | 2025-06-29 | This PowerShell script adds objects to an O365 protection job. New jobs will be created automatically so that all objects will be protected and each job will have a maximum number of objects based on the -maxObjectsPerJob setting. |
| [downloadM365Files.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/downloadM365Files) | PowerShell | 2026-03-04 | This PowerShell script downloads files from M365 OneDrive and Sharepoint. |
| [downloadM365MailboxPST.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/downloadM365MailboxPST) | PowerShell | 2026-04-16 | This PowerShell script downloads an M365 mailbox backup as a PST. |
| [downloadM365MailboxPST.py](https://github.com/cohesity/community-automation-samples/tree/main/python/downloadM365MailboxPST) | Python | 2024-11-04 | This script downloads an M365 mailbox backup as a PST. |
| [excludeMailboxes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/excludeMailboxes) | PowerShell | 2024-11-04 | This PowerShell script excludes user mailboxes from an O365 Exchange protection job. It takes as input a list of user names or SMTP addresses. |
| [excludeProtectedSharepointSites.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/excludeProtectedSharepointSites) | PowerShell | 2024-11-04 | This PowerShell script excludes protected Sharepoint sites from an autoprotect (catch-all) protection job. |
| [includeMailboxes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/includeMailboxes) | PowerShell | 2024-11-04 | This PowerShell script adds user mailboxes to an O365 Exchange protection job. It takes as input a list of user names or SMTP addresses. |
| [protectO365Mailboxes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectO365Mailboxes) | PowerShell | 2024-11-04 | This PowerShell script adds mailboxes to an O365 protection job. |
| [protectO365OneDrive.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectO365OneDrive) | PowerShell | 2024-11-04 | This PowerShell script adds Onedrive users to an O365 protection job. |
| [protectO365PublicFolders.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectO365PublicFolders) | PowerShell | 2024-11-04 | This PowerShell script adds Public Folders to an O365 protection job. |
| [protectO365Sites.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectO365Sites) | PowerShell | 2024-11-04 | This PowerShell script adds Sites to an O365 protection job. |
| [protectO365Teams.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectO365Teams) | PowerShell | 2024-11-04 | This PowerShell script adds teams to an O365 protection job. |
| [protectSharepointSites.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectSharepointSites) | PowerShell | 2024-11-04 | This PowerShell script adds Sharepoint sites to an existing O365 protection job. |
| [recoverExchangeDB.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverExchangeDB) | PowerShell | 2024-11-04 | This powershell script recovers an Exchange mailbox database to a Cohesity view. |
| [registerExchange.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/registerExchange) | PowerShell | 2024-11-04 | This PowerShell script registers physical servers as Exchange servers. |
| [registerExchangeV2.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/registerExchangeV2) | PowerShell | 2026-10-09 | This PowerShell script registers an O365 Recovery To Exchange Server source. |
| [restoreM365Mailbox.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreM365Mailbox) | PowerShell | 2026-09-27 | This script restores one or more M365 mailboxes protected by a customer-managed Cohesity cluster, either back to the original mailbox or to an alternate target mailbox. |
| [restoreM365Onedrive.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreM365Onedrive) | PowerShell | 2026-09-27 | This script restores one or more M365 OneDrives. |
| [unprotectedO365Objects.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/unprotectedO365Objects) | PowerShell | 2024-11-04 | This PowerShell script lists unproteccted O365 Objects. |
| [unprotectMailboxes.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/unprotectMailboxes) | PowerShell | 2025-06-10 | This PowerShell script unselects user mailboxes from an O365 Exchange protection job. It takes as input a list of user names or SMTP addresses. |
| [unprotectMissingO365Objects.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/unprotectMissingO365Objects) | PowerShell | 2024-11-04 | This PowerShell script removes missing objects from O365 protection groups. |
| [unprotectMissingSharepointSites.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/unprotectMissingSharepointSites) | PowerShell | 2024-11-04 | This PowerShell script removes missing Sharepoint sites from an O365 protection job. |
| [updateO365Credentials.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateO365Credentials) | PowerShell | 2024-11-04 | This PowerShell script sets the O365 username/password and app ID/SecretKey for an O365 protection source. |
