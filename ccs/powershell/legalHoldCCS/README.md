# Add/Remove Legal Hold from CCS Objects using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script adds or removes legal hold from CCS backups.

Note: this script is a work in progress. As of now, it will add/remove legal hold on M365 mailboxes and onedrive objects only.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'legalHoldCCS'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [legalHoldCCS.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/legalHoldCCS/legalHoldCCS.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

Add legal hold to M365 mailboxes backed up on 2025-07-08:

```powershell
./legalHoldCCS.ps1 -date '2025-07-08' -addHold
```

Add legal hold to M365 onedrives backed up on 2025-07-08:

```powershell
./legalHoldCCS.ps1 -date '2025-07-08' -addHold -objectType onedrive
```

Show onedrives with legal hold enabled:

```powershell
./legalHoldCCS.ps1 -date '2025-07-08' -objectType onedrive -showTrue
```

## Parameters

* -username: (optional) used for password storage only (default is 'ccs')
* -password: (optional) enter API key (will be prompted if omitted and not already stored)
* -noPrompt: (optional) do not prompt for password
* -date: (optional) date of backups e.g. '2025-07-08' (opeate on backups that occurred on this date)
* -startDate: (optional) operate on backups that ran on or after this date
* -endDate: (optional) operate on backups that ran on or before this date
* -addHold: (optional) add legal hold
* -removeHold: (optional) remove legal hold
* -showTrue: (optional) show objects that are on legal hold
* -showFalse: (optional) show objects that are not on legal hold
* -objectType: (optional) mailbox, onedrive, sharepoint (default is mailbox)
* -range: (optional) adjust API query range (days) for performance (default is 4)
* -dbg : (optional) output debug information to text file (debug-legalHoldCCS.txt)

## Date Selection

You can specify -date which will include backups that occurred from that date to 24 hours after that date, or you can specify a -startDate and -endDate which will include the backups that occurred between those dates.

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
