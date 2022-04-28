# Include Teams in O365 Protection using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script adds Teams to an O365 Teams protection job. It takes as input a list of team names or SMTP addresses.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'protectO365Mailboxes'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* protectO365Mailboxes.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together. You can provide a list of teams at the command line, or create a text file and populate with the team names or SMTP addresses (one per line)

Note that the team names should be in the exact same format as shown in O365. Alternatively you can use the primary SMTP address of the team.

Then, run the main script like so:

```powershell
# example - adding teams from the command line
./protectO365Mailboxes.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName 'My Job' -teams my-team1, my-team2
# end example
```

or

```powershell
# example - adding teams from a text file
./protectO365Mailboxes.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName 'My Job' -teamList ./myTeamlist.txt
# end example
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of team (defaults to local)
* -jobName: name of the O365 protection job to exclude mailboxes from
* -teams: a comma separated list of team names or smtp addresses to add
* -teamList: a text file list of team names or SMTP addresses to add
