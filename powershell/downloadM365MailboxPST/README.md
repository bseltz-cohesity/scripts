# Download M365 Mailbox as PST Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script downloads an M365 mailbox backup as a PST.

`Note`: this script is under development and is not yet fully functional.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'downloadM365MailboxPST'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [downloadM365MailboxPST.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/downloadM365MailboxPST/downloadM365MailboxPST.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./downloadM365MailboxPST.ps1 -vip mycluster `
                             -username myusername `
                             -domain mydomain.net `
                             -sourceUserName someuser1@mydomain.onmicrosoft.com, someuser2@mydomain.onmicrosoft.com `
                             -fileName .\mypst.zip `
                             -pstPassword bosco
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -sourceUserName: (optional) one or more user names or SMTP to download (comma separated)
* -sourceUserList: (optional) text file of user names to download (one per line)
* -fileName: (optional) path/name of zip file to download (default is '.\pst.zip')
* -pstPassword: (optional) password for PSTs (will be no password if omitted)
* -promptForPSTPassword: (optional) prompt for PST password
* -recoverDate: (optional) datetime of snapshot to download e.g '2024-05-10 23:30:00' (will use latest snapshot if omitted)
* -continueOnError: (optional) continue processing if mailbox not found (exit is default)
* -sleepTimeSeconds: (optional) sleep X seconds between status queries (default is 30)
