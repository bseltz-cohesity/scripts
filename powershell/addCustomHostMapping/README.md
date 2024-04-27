# Add Custom Host Mappings Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script adds a customer host mapping to Cohesity.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'addCustomHostMapping'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [addCustomHostMapping.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/addCustomHostMapping/addCustomHostMapping.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./addCustomHostMapping.ps1 -vip mycluster `
                           -username myusername `
                           -domain mydomain.net `
                           -ip 192.168.1.110 `
                           -hostNames myserver, myserver.mydomain.net
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -ip: (optional) IP address of host mapping
* -hostNames: (optional) one or more host names to associate with the IP address (comma separated)
* -inputFile: (optional) csv file containing ip,hostname1,hostname2,hostname(n)
* -backup: (optional) backup existing host mappings to file hosts-backup-date.csv
* -overwrite: (optional) if IP already exists, replace the host names (default is to append new host names)
* -delete: (optional) delete host mappings for the specified IP(s)
