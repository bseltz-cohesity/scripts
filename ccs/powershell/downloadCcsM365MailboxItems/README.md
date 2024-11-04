# Download Ccs M365 Mailbox Items using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script searches for mailbox items in a Ccs M365 Mailbox and downloads them as a PST file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'downloadCcsM365MailboxItems'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [downloadCcsM365MailboxItems.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/downloadCcsM365MailboxItems/downloadCcsM365MailboxItems.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./downloadCcsM365MailboxItems.ps1 -mailboxName someuser@mydomain.onmicrosoft.com `
                                  -emailSubject "test" `
                                  -senderAddress otheruser@mydomain.onmicrosoft.com
```

## Basic Parameters

* -username: (optional) used for password storage only (default is 'Ccs')
* -mailboxName: (optional) mailbox name to search

## Search Parameters

* -emailSubject: (optional) text to search in email subject
* -senderAddress: (optional) filter on emails from this address
* -receivedStartTime: (optional) filter on emails received after this date/time (e.g. 2024-07-22 00:00:00)
* -receivedEndTime: (optional) filter on emails received before this date/time (e.g. 2024-07-22 23:30:00)

## Other Parameters

* -fileName: (optional) path/name of zip file to download (default is '.\pst.zip') multiple zip files will be downloaded if emails are stored in multiple timestamps (numerator will be appended if there are multiple files)
* -timestamp: (optional) specify timestamp of a specific snapshot (use -showTimestamps to list)
* -showTimestamps: (optional) list timestamps of backups returned by search
* -recoverDate: (optional) restore latest snashot on or before this date (default is latest backup)
* -pstPassword: (optional) password for PSTs (will be no password if omitted)
* -promptForPSTPassword: (optional) prompt for PST password
* -pageSize: (optional) limit number of objects returned pr page (default is 1000)
* -sleepTimeSeconds: (optional) sleep X seconds between status queries (default is 30)

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
