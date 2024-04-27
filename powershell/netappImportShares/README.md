# Migrate SMB Shares from NetApp Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script migrates SMB shares from NetApp. The script assumes that the NetApp volumes have been protected by Cohesity. The script will restore the volumes as Cohesity views, create nested shares and apply share permissions. The share information is exported from NetApp using the NetApp PowerShell Toolkit.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'netappImportShares'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* netAppImportShares.ps1: the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder.

## Exporting Share Information from NetApp

Download the [NetApp PowerShell Toolkit here](https://mysupport.netapp.com/site/tools/tool-eula/5e58da8972f71828cfdf9cbb)

Then you can export the share information like so:

```powershell
# export cifs shares from NetApp
Connect-NcController -Name mynetapp-controller.mydomain.net -Vserver SVM1 -HTTPS
$netappShares = Get-NcCifsShare
$netappShares | ConvertTo-Json -Depth 99 | Out-File -FilePath ./netappShares.json
# end
```

## Importing the Shares into Cohesity

After the information has been exported from NetApp, we can import into Cohesity:

```powershell
# example
.\netappImportShares.ps1 -vip mycluster `
                         -username myusername `
                         -domain mydomain.net `
                         -importFile .\netappShares.json `
                         -netappSource mynetapp `
                         -volumeName vol1, vol2 `
                         -viewPrefix ntap- `
                         -exclude 'test', 'snapshot' `
                         -restrictVolumeSharePermissions 'mydomain.net\domain admins', 'mydomain.net\storage admins'
# end example
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -importFile: path to NetApp output file (e.g. .\netappShares.json)
* -netappSource: name of NetApp protection source
* -volumeName: (optional) list of volumes to migrate (e.g. vol1, vol2) if omitted, all volumes are migrated
* -volumeList: (optional) text file list volumes to migrate (e.g. .\volumes.txt) if omitted, all volumes are migrated
* -viewPrefix: (optional) prefix to apply to volume/view level shares (e.g. ntap-)
* -sharePrefix: (optional) prefix to apply to shares (e.g. ntap-)
* -exclude: (optional) comma separated list of substrings - exclude shares that match
* -copySharePermissions: (optional) if omitted, share permissions are not copied
* -restrictVolumeSharePermissions: (optional) restrict share permissions for volume/view level shares (e.g. 'mydomain.net\domain admins', 'mydomain.net\storage admins')
* -smbOnly: (optional) restrict views/shares to SMB protocol only
