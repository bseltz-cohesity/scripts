# Deploy a SaaS Connector using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script can deploy a SaaS Connector OVA on VMware.

Note: This script requires vSphere PowerCLI to be installed.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'deploySaaSConnector'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/ccs/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [deploySaaSConnector.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/powershell/deploySaaSConnector/deploySaaSConnector.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

Download the OVA from Helios:

```powershell
./deploySaaSConnector.ps1 -downloadOVA `
                          -region us-east-2 `
                          -downloadPath E:\
```

Deploy the OVA:

```powershell
./deploySaaSConnector.ps1 -deployOVA `
                          -region us-east-2 `
                          -vmName saasConnector1 `
                          -vCenter myvcenter.mydomain.net `
                          -vmHost myhost1 `
                          -vmDatastore datastore1 `
                          -vmNetwork 'VM Network' `
                          -ip 10.1.1.100 `
                          -netmask 255.255.255.0 `
                          -gateway 10.1.1.1 `
                          -diskFormat Thin
```

Register SaaS Connector:

```powershell
./deploySaaSConnector.ps1 -registerSaaSConnector `
                          -region us-east-2 `
                          -ip 10.1.1.100 `
                          -domainNames mydomain.net `
                          -dnsServers 10.1.1.200, 10.1.1.201 `
                          -ntpServers time.google.com, pool.ntp.org
```

Unregister SaaS Connector:

```powershell
./deploySaaSConnector.ps1 -unregisterSaaSConnector `
                          -region us-east-2 `
                          -ip 10.1.1.100
```

## Common Parameters

* -region: specify region (e.g. us-east-2)
* -vmName: (optional) name of SaaS Connector VM to create or manage

## Cohesity Authentication Parameters

* -username: (optional) username to connect to Helios (default is 'Ccs')
* -password: (optional) API key to connect to Helios (will be prompted if omitted and not already stored)

## OVA Deployment Parameters

* -deployOVA: (optional) perform OVA deployment
* -ovfPath: (optional) path to downloaded OVA file
* -saasConnectorPassword: (optional) new admin password for SaaS connector (will be prompted if omitted)
* -returnIp: (optional) return IP address (helpful if DHCP was used)
* -vCenter: (optional) vCenter to connect to
* -vmHost: (optional) vSphere host to deploy OVA to
* -vmDatastore: (optional) vSphere datastore to deploy OVA to
* -folderName: (optional) name of VM folder to place new VM
* -parentFolderName: (optional) name of parent folder (if -folderName is not unique)
* -diskFormat: (optional) Thin or Thick (default is Thick)
* -vmNetwork: name of VM network for primary interface
* -ip: (optional) IP address of primary network interface (DHCP will be used if omitted)
* -netmask: (optional) subnet mask for primary network interface
* -gateway: (optional) default gateway for primary network interface
* -vmNetwork2: (optional) name of VM network for second interface
* -ip2: (optional) IP address of second network interface
* -netmask2: (optional) subnet mask for second network interface
* -gateway2: (optional) default gateway for second network interface

## Download Parameters

* -downloadOVA: (optional) download the OVA file
* -downloadPath: (optional) path to download OVA file (defaul is '.')

## Helios Registration Parameters

* -registerSaaSConnector: (optional) register SaaS connector to Helios
* -connectionName: (optional) register to existing SaaS Connection name
* -dnsServers: (optional) one or more DNS server addresses (comma separated)
* -ntpServers: (optional) one or more NTP servers (comma separated)
* -domainNames: (optional) one or more domain names (comm separated)
* -unregisterSaaSConnector: (optional) unregister SaaS connector from Helios

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
