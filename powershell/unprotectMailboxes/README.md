# Unprotect Mailboxes from O365 Protection using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script unselects user mailboxes from an O365 Exchange protection job. It takes as input a list of user names or SMTP addresses.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'unprotectMailboxes'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [unprotectMailboxes.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/unprotectMailboxes/unprotectMailboxes.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module
* excludedMailboxes.txt: a text file containing a list of user names or primary smtp addresses to exclude from the job

Place all files in a folder together. Create a text file called excludedMailboxes.txt and populate with the user names or SMTP addresses, like so:

```text
mmurdoc.mydomain.com
Stan Lee
Joey Bagadonuts
```

Note that the user names should be in the exact same format as shown in O365. Alternatively you can use the primary SMTP address of the user.

Then, run the main script like so:

```powershell
./unprotectMailboxes.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName 'My Job' -exclusionList ./excludedMailboxes.txt
```

```text
Connected!
Matt Murdock already excluded
Excluding Stan Lee
Can't find user Joey Bagadonuts - skipping
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -jobName: name of the O365 protection job to exclude mailboxes from
* -users: (optional) user names or SMTP addresses to exclude (comma separated)
* -userList: (optional) a text file list of user names or SMTP addresses to exclude (one per line)
