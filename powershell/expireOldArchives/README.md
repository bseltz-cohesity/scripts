# Expire Old Archives using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script expires archives older than x days. This is useful if you want to reduce your long term archive retention to reduce storage consumption in the cloud or other archive target.

## Warning! This script deletes backup data! Make sure you know what you are doing before you run it!  

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/expireOldArchives/expireOldArchives.ps1).content | Out-File expireOldArchives.ps1; (Get-Content expireOldArchives.ps1) | Set-Content expireOldArchives.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/expireOldArchives/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* expireOldArchives.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

First, run the script WITHOUT the -expire switch to see what would be deleted.

```powershell
powershell> ./expireOldArchives.ps1 -vip 10.99.1.64 -username admin -olderThan 120            
Connected!
searching for old snapshots...
07/01/2018 00:38:02  hdname
08/01/2018 07:42:44  hdname
08/03/2018 13:39:18  JZ Cloud Archive
08/03/2018 15:51:37  JZ Cloud Archive
08/04/2018 13:38:00  JZ Cloud Archive
```
Then, if you're happy with the list of archives that will be deleted, run the script again and include the -expire switch. THIS WILL DELETE THE OLD ARCHIVES!!!

```powershell
./expireOldArchives.ps1 -vip 10.99.1.64 -username admin -olderThan 120 -expire
```

You can run the script again you should see no results.

Also note that data in the archive target may not be immediately deleted if a newer reference archive has not yet been created. 
