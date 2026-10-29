# Restore an M365 Mailbox using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script restores one or more M365 mailboxes protected by a customer-managed Cohesity cluster, either back to the original mailbox, to an alternate target mailbox or to a cusrtomer-managed Exchange server.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreM365Mailbox'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreM365Mailbox.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/restoreM365Mailbox/restoreM365Mailbox.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
./restoreM365Mailbox.ps1 -vip mycluster `
                         -username myusername `
                         -domain mydomain.net `
                         -sourceUserName jsmith@mydomain.net
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster, or Helios endpoint (defaults to helios.cohesity.com)
* -username: name of user to connect to Cohesity cluster (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -tenant: (optional) tenant organization name to impersonate
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -mcm: (optional) connect through Helios/MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: name of the registered cluster to access (required when connecting through Helios/MCM)

## Restore Parameters

* -sourceUserName: one or more mailbox names or SMTP addresses to restore (comma separated)
* -sourceUserList: (optional) path to a text file of mailbox names/SMTP addresses, one per line
* -csvFile: (optional) path to a CSV file of mailboxes to restore, with optional per-mailbox overrides (see [CSV File Format](#csv-file-format))
* -source: (optional) name of the registered M365 source, used to disambiguate mailboxes protected under more than one source
* -jobName: (optional) name of protection group to restore from
* -recoverDate: (optional) restore from the latest snapshot taken before this date/time (defaults to the most recent snapshot)
* -targetMailbox: (optional) name or SMTP address of a mailbox to restore into, instead of the original mailbox
* -targetSource: (optional) name of the registered M365 source that owns -targetMailbox, if it differs from -source
* -folderPrefix: (optional) top-level folder name to restore into when using -targetMailbox (defaults to 'restore'; when restoring a single mailbox, contents land in `<folderPrefix>-<sourceUserName>`; when restoring multiple mailboxes in one task, all contents land in `<folderPrefix>`)
* -excludeBefore: (optional) incremental restore: exclude mail, calendar and contact items dated before this date/time, e.g. '2026-10-29' or '2026-10-29 10:30:00' (local time)
* -excludeAfter: (optional) incremental restore: exclude mail, calendar and contact items dated after this date/time (local time)
* -continueOnError: (optional) skip mailboxes that can't be found or have no matching snapshot, instead of exiting
* -ewsExchangeTarget: (optional) restore mailboxes to on-prem Exchange server
* -smtpAddressOverride: (optional) restore to mailbox with specified SMTP address (single source mailbox only; use -csvFile for multiple)
* -sidOverride: (optional) restore to mailbox with specified SID (single source mailbox only; use -csvFile for multiple)
* -mailboxGuidOverride: (optional) restore to mailbox with specified mailbox GUID (single source mailbox only; use -csvFile for multiple)

## CSV File Format

Use -csvFile to specify a per-mailbox `smtpAddressOverride`, `sidOverride` or `mailboxGuidOverride`. The `sourceUserName` column is required; the override columns are optional, and blank values are ignored. Mailboxes in the CSV are combined with any specified using -sourceUserName or -sourceUserList.

```text
sourceUserName,smtpAddressOverride,sidOverride,mailboxGuidOverride
jsmith@mydomain.net,jsmith2@mydomain.net,,
bwilson@mydomain.net,,S-1-5-21-1111111111-2222222222-3333333333-1001,
mjones@mydomain.net,,,aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
```

## Notes

All mailboxes are restored in a single restore task. With -continueOnError, mailboxes that can't be found or have no matching snapshot are skipped and the rest are restored (the option is also passed to the restore task itself).

## Incremental Restore

Use -excludeBefore and/or -excludeAfter to restore only items within a date range. Dates are converted to epoch seconds and applied to mail, calendar and contact items. Notes and tasks are not date-filtered and are restored in full. -excludeBefore must be earlier than -excludeAfter if both are specified.

## Examples

Restore a single mailbox in place, from the most recent snapshot:

```powershell
./restoreM365Mailbox.ps1 -vip mycluster ` 
                         -username myusername `
                         -domain mydomain.net `
                         -sourceUserName jsmith@mydomain.net
```

Restore several mailboxes read from a text file:

```powershell
./restoreM365Mailbox.ps1 -vip mycluster `
                         -username myusername `
                         -domain mydomain.net `
                         -sourceUserList .\mailboxes.txt
```

Restore several mailboxes with per-mailbox overrides from a CSV file:

```powershell
./restoreM365Mailbox.ps1 -vip mycluster `
                         -username myusername `
                         -domain mydomain.net `
                         -csvFile .\mailboxes.csv
```

Restore mailboxes to a point in time, skipping any mailbox with no matching snapshot rather than stopping:

```powershell
./restoreM365Mailbox.ps1 -vip mycluster `
                         -username myusername `
                         -domain mydomain.net `
                         -sourceUserName jsmith@mydomain.net,bwilson@mydomain.net `
                         -recoverDate '2026-09-01 08:00:00' `
                         -continueOnError
```

Restore a mailbox into a different (alternate) mailbox, under a named top-level folder:

```powershell
./restoreM365Mailbox.ps1 -vip mycluster `
                         -username myusername `
                         -domain mydomain.net `
                         -sourceUserName jsmith@mydomain.net `
                         -targetMailbox archive-admin@mydomain.net `
                         -folderPrefix recovered
```

Restore only items from a date range (incremental restore):

```powershell
./restoreM365Mailbox.ps1 -vip mycluster `
                         -username myusername `
                         -domain mydomain.net `
                         -sourceUserName jsmith@mydomain.net `
                         -excludeBefore '2026-10-29' `
                         -excludeAfter '2026-10-29 10:30:00'
```

Restore through Helios/MCM to a specific registered cluster:

```powershell
./restoreM365Mailbox.ps1 -vip helios.cohesity.com `
                         -username myusername `
                         -mcm `
                         -clusterName mycluster `
                         -sourceUserName jsmith@mydomain.net
```
