# List Available Revoery Points for an Object Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script searches for an object and displays the versions available for recovery.

## Components

* objectRecoveryPoints.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```powershell
./objectRecoveryPoints.ps1 -vip mycluster -username myusername -domain mydomain.net -objectname myvm
```

```text
Connected!
ObjectName             JobName                StartTime              ExpiryTime             DaysToExpiration
myvm                VM Backup              4/23/19 11:20:01 PM    4/28/19 11:20:45 PM    5
myvm                VM Backup              4/22/19 11:20:00 PM    4/27/19 11:20:47 PM    4
myvm                VM Backup              4/21/19 11:20:00 PM    4/26/19 11:20:45 PM    3
myvm                VM Backup              4/20/19 11:20:01 PM    4/25/19 11:20:43 PM    2
myvm                VM Backup              4/19/19 11:20:01 PM    4/24/19 11:20:47 PM    1
myvm                VM Backup              4/18/19 11:20:00 PM    4/28/19 11:20:00 PM    5
myvm                VM Backup              4/17/19 11:20:00 PM    4/27/19 11:20:00 PM    4
myvm                VM Backup              4/16/19 11:20:01 PM    4/26/19 11:20:01 PM    3
myvm                VM Backup              4/15/19 11:20:01 PM    4/25/19 11:20:01 PM    2
myvm                VM Backup              4/14/19 11:20:00 PM    4/24/19 11:20:00 PM    1
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: user to authenticate to Cohesity
* -domain: domain of user (defaults to local)
* -objectname: name of object to search for

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/objectRecoveryPoints/objectRecoveryPoints.ps1).content | Out-File objectRecoveryPoints.ps1; (Get-Content objectRecoveryPoints.ps1) | Set-Content objectRecoveryPoints.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/objectRecoveryPoints/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```
