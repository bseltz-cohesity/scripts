# Auto-Protect Ccs M365 Mailboxes (Exclude List) using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script turns on auto-protection for all Ccs M365 mailboxes under a registered source, while excluding any mailboxes listed in a CSV file from that auto-protection.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'autoprotectCcsM365MailboxesCSV'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [autoprotectCcsM365MailboxesCSV.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/autoprotectCcsM365MailboxesCSV/autoprotectCcsM365MailboxesCSV.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Create a CSV file (or export from M365) containing the mailboxes you want to exclude from auto-protection. Each row must identify the mailbox by its primary SMTP address, its display name, or both. The recognized columns are:

* smtpAddress (or email, or primarySMTPAddress): the mailbox's primary SMTP address
* name: the mailbox's display name

If a row has both an address and a name, the address is used for matching. So for example, our CSV file might look like this:

```text
name,smtpAddress
Adele Vance,adelev@myorg.onmicrosoft.com
Alex Wilber,alexw@myorg.onmicrosoft.com
```

Place both files in a folder together and run the main script like so:

```powershell
./autoprotectCcsM365MailboxesCSV.ps1 -region us-east-2 `
                                      -sourceName mydomain.onmicrosoft.com `
                                      -policyName Gold `
                                      -csvFile ./mailboxes.csv
```

## How it works

The script enables auto-protection on the Users node of the specified M365 source, so any current or future mailbox under that source is protected by default. It then looks up each mailbox listed in the CSV and adds it to the exclusion list, so those specific mailboxes are left out of auto-protection. Mailboxes that can't be found are reported and skipped.

If the Users node is already protected, the script updates the existing protection configuration instead of creating a new one, and any exclusions already in place are kept. The one exception is that existing exclusions for mailboxes that no longer exist (for example, mailboxes deleted from M365) are detected and removed, and each removal is reported in the output.

## Parameters

* -username: (optional) used for password storage only (default is 'DMaaS')
* -region: (required) specify region (e.g. us-east-2)
* -sourceName: (required) name of registered M365 protection source
* -policyName: (required unless -useMBS is specified) name of protection policy to use
* -csvFile: (optional) name of CSV file containing mailboxes to exclude from auto-protection
* -startTime: (optional) e.g. '18:30' (defaults to '20:00', i.e. 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/New_York')
* -incrementalSlaMinutes: (optional) default 1440
* -fullSlaMinutes: (optional) default 1440
* -useMBS: (optional) use Microsoft 365 Backup Storage
* -dbg: (optional) enable the Cohesity API debugger

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
