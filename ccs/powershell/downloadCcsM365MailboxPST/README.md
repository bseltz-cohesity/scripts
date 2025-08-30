# Download Ccs M365 Mailboxes to PST using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script downloads M365 mailbox backups in CCS and downloads them as a PST file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'downloadCcsM365MailboxPST'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [downloadCcsM365MailboxPST.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/downloadCcsM365MailboxPST/downloadCcsM365MailboxPST.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./downloadCcsM365MailboxPST.ps1 -mailboxName someuser@mydomain.onmicrosoft.com
```

## Basic Parameters

* -username: (optional) used for password storage only (default is 'Ccs')
* -mailboxName: (optional) one or more mailbox names to download (comma separated)
* -mailboxList: (optional) text file of mailboxes to download (one per line)

## Other Parameters

* -outputPath: (optional) folder to download PST files (default is '.')
* -recoverDate: (optional) restore latest snashot on or before this date (default is latest backup)
* -pstPassword: (optional) password for PSTs (will be no password if omitted)
* -promptForPSTPassword: (optional) prompt for PST password
* -pageSize: (optional) limit number of objects returned pr page (default is 1000)
* -sleepTimeSeconds: (optional) sleep X seconds between status queries (default is 30)
* -useMBS: (optional) restore mailboxes from MBS storage

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
