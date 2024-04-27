# Add NTFS Permissions to a View using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script adds NTFS permissions to a view. Note that new NTFS permissions will not propagate to existing files and folders and will only be present at the root of the view and propagate to new files and folders created after the new permissions have been added.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
$scriptName = 'addNTFSPermissions'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* [addNTFSPermissions.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/addNTFSPermissions/addNTFSPermissions.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
#example
./addNTFSPermissions.ps1 -vip mycluster `
                         -username myusername `
                         -domain mydomain.net `
                         -viewName myview `
                         -readWrite mydomain.net\user1 `
                         -fullControl mydomain.net\admingroup1, mydomain.net\admingroup2
#end example
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain (defaults to 'local')
* -viewName: name of new view to create
* -fullControl: (optional) comma separated list of principals to grant full control
* -readWrite: (optional) comma separated list of principals to grant read/write access
* -modify: (optional) comma separated list of principals to grant modify access
* -readOnly: (optional) comma separated list of principals to grant read only access
