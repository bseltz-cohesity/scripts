# Add a VLAN Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script adds a VLAN to the networking configuration of a Cohesity cluster.  

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'addVlan'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/vlanConfigExample.ps1").content | Out-File "vlanConfigExample.ps1"; (Get-Content "vlanConfigExample.ps1") | Set-Content "vlanConfigExample.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [addVlan.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/addVlan/addVlan.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module
* [vlanConfigExample.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/addVlan/vlanConfigExample.ps1): example configuration file

Place the files in a folder together and run the main script like so:

```powershell
# Command line example
./addVLAN.ps1 -cluster mycluster `
              -username myuser `
              -domain mydomain.net `
              -vlanId 60 `
              -cidr 192.168.60.0/24 `
              -vip 192.168.60.2, 192.168.60.3, 192.168.60.4 `
              -gateway 192.168.60.254 `
              -hostname mycluster.net60.net
# End example
```

## Parameters

* -cluster: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: Active Directory domain of user (defaults to local)
* -vlanId: VLAN ID to add to the cluster
* -cidr: CIDR of new VLAN
* -vip: One or more VIPs to add to the new VLAN
* -gateway: (Optional) default gateway for new VLAN
* -hostname: (Optional) custom hostname for cluster on new VLAN
* -configFile: (Optional) provide the above parameters in a config file
* -delete: (optional) delete an existing VLAN

## Using a Config File

If you don't want to provide all the parameters on the command line, you can provide a config file. The config file should contain any VLAN parameters you want to provide. Like so:

```powershell
# config file example

# VLAN ID
$vlanId = 60

# CIDR of new VLAN
$cidr = '192.168.60.0/24'

# VIPs to add
$vip = '192.168.60.5', '192.168.60.6', '192.168.60.7'

# Optional gateway for new VLAN
$gateway = '192.168.60.254'

# Optional hostname for new VLAN
$hostname = 'mycluster.net60.net'

# End configFile
```

Save the above as a .ps1 file like myVLAN.ps1 and then you can use the config file in your command, like:

```powershell
# using config file example
./addVLAN.ps1 -cluster mycluster `
              -username myuser `
              -domain mydomain.net `
              -configFile myVLAN.ps1
```
