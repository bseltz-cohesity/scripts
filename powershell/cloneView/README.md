# Clone a Cohesity View using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script clones an active or replicated view.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cloneView'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [cloneView.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cloneView/cloneView.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./cloneView.ps1 -vip mycluster `
                -username admin `
                -domain local `
                -viewName SMBShare `
                -newName Cloned-SMBShare
```

By default, the latest available backup will be used. If you want to specify a particular date, then you can list the versions using the -showVersions or -showDates parameters, like so:

```powershell
./cloneView.ps1 -vip mycluster `
                -username admin `
                -domain local `
                -viewName SMBShare `
                -newName Cloned-SMBShare `
                -showVersions
```

Then yuo can use the -backupDate parameter with an available version, like:

```powershell
./cloneView.ps1 -vip mycluster `
                -username admin `
                -domain local `
                -viewName SMBShare `
                -newName Cloned-SMBShare `
                -backupDate '2020/12/30 23:00'
```

You can also specify an archival target to clone from using the -vaultName parameter:

```powershell
./cloneView.ps1 -vip mycluster `
                -username admin `
                -domain local `
                -viewName SMBShare `
                -newName Cloned-SMBShare `
                -backupDate '2020/12/30 23:00' `
                -vaultName 'My External Target'
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -viewName: name of source view to clone
* -newName: name of target view to create
* -vaultName: (optional) name of archive target to clone from
* -backupDate: (optional) date of backup (acceptable formats are 'YYYY/MM/dd' or 'YYYY/MM/dd HH:mm')
* -showDates: (optional) list available backup dates in 'YYYY/MM/dd' format
* -showVersions: (optional) list available backup dates in 'YYYY/MM/dd HH:mm' format
