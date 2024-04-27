# Migrate NetApp 7-mode to Cohesity Views Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script migrates SMB shares from NetApp. The script assumes that the NetApp volumes have been protected by Cohesity. The script will restore the volumes as Cohesity views, create nested shares and apply share permissions. The share information is exported from NetApp using the NetApp PowerShell Toolkit.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'netapp7migration'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/netapp7ImportSMB.ps1").content | Out-File "netapp7ImportSMB.ps1"; (Get-Content "netapp7ImportSMB.ps1") | Set-Content "netapp7ImportSMB.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/netapp7ImportNFS.ps1").content | Out-File "netapp7ImportNFS.ps1"; (Get-Content "netapp7ImportNFS.ps1") | Set-Content "netapp7ImportNFS.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/netapp7Export.ps1").content | Out-File "netapp7Export.ps1"; (Get-Content "netapp7Export.ps1") | Set-Content "netapp7Export.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [netapp7Export.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/netapp7migration/netapp7Export.ps1): export netapp 7-mode configuration details
* [netapp7ImportSMB.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/netapp7migration/netapp7ImportSMB.ps1): import netapp 7-mode SMB shares
* [netapp7ImportNFS.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/netapp7migration/netapp7ImportNFS.ps1): import netapp 7-mode NFS exports
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together.

## Exporting Share Information from NetApp

Download the [NetApp PowerShell Toolkit here](https://mysupport.netapp.com/site/tools/tool-eula/5e58da8972f71828cfdf9cbb)

Then you can export the share information like so:

```powershell
# export configuration from NetApp
.\netapp7Export.ps1 -controllerName mynetapp7.mydomain.net
# end
```

## Importing the SMB Shares into Cohesity

After the information has been exported from NetApp, we can import SMB shares into Cohesity:

```powershell
# example
.\netapp7ImportSMB.ps1 -vip mycohesity `
                       -username myusername `
                       -domain mydomain.net `
                       -shareNames vol0, vol1 `
                       -controllerName mynetapp7.mydomain.net `
                       -copySharePermissions
# end example
```

## Parameters for netapp7ImportSMB.ps1

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -controllerName: Name of netapp controller (must match host name of protected mount points)
* -shareNames: (optional) list of shares to migrate, comma separated (e.g. vol1, vol2)
* -shareList: (optional) text file list of shares to migrate (e.g. .\shares.txt)
* -allShares: (optional) migrate all protected shares
* -viewPrefix: (optional) prefix to apply to volume/view level shares (e.g. ntap-)
* -sharePrefix: (optional) prefix to apply to shares (e.g. ntap-)
* -copySharePermissions: (optional) if omitted, share permissions are not copied
* -hideViews: (optional) views are creates with trailing $ in the name so they are not browseable

## Importing the NFS Exports into Cohesity

After the information has been exported from NetApp, we can import NFS exports into Cohesity:

```powershell
# example
.\netapp7ImportNFS.ps1 -vip mycohesity `
                       -username myusername `
                       -domain mydomain.net `
                       -exportPaths /vol/vol0, /vol/vol1 `
                       -controllerName mynetapp7.mydomain.net `
# end example
```

## Parameters for netapp7ImportNFS.ps1

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -controllerName: Name of netapp controller (must match host name of protected mount points)
* -exportPaths: (optional) list of shares to migrate, comma separated (e.g. vol1, vol2)
* -exportPathList: (optional) text file list of shares to migrate (e.g. .\shares.txt)
* -allExports: (optional) migrate all protected shares
* -viewPrefix: (optional) prefix to apply to volume/view level shares (e.g. ntap-)
