# Include Mailboxes in O365 Protection using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script adds user mailboxes to an O365 Exchange protection job. It takes as input a list of user names or SMTP addresses.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'includeMailboxes'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [includeMailboxes.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/includeMailboxes/includeMailboxes.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. You can provide a list of users at the command line, or create a text file and populate with the user names or SMTP addresses, like so:

```text
mmurdoc@mydomain.com
Stan Lee
Joey Bagadonuts
```

Note that the user names should be in the exact same format as shown in O365. Alternatively you can use the primary SMTP address of the user.

Then, run the main script like so:

```powershell
# example - adding users from the command line
./includeMailboxes.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName 'My Job' -users 'Stan Lee', 'mmurdoc@mydomain.com'
# end example
```

or

```powershell
# example - adding users from a text file
./includeMailboxes.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName 'My Job' -userList ./myuserlist.txt
# end example
```

```text
Connected!
Matt Murdock already added
Adding Stan Lee
Can't find user Joey Bagadonuts - skipping
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -jobName: name of the O365 protection job to exclude mailboxes from
* -users: a comma separated list of usernames or smtp addresses to add
* -userList: a text file list of user names or SMTP addresses to add
* -pageSize: number of objects to per query (default is 1000)
