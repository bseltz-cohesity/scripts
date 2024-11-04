# Add or Remove Remote Cluster IP Addresses using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script adds or removes IP addresses from a remote cluster configuration.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'remoteIPs'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [remoteIPs.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/remoteIPs/remoteIPs.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then run the script like so:

To view the current remote IPs:

```powershell
./remoteIPs.ps1 -vip mycluster `
                -username myuser `
                -domain mydomain.net `
                -remoteCluster cluster2
```

To add an IP:

```powershell
./remoteIPs.ps1 -vip mycluster `
                -username myuser `
                -domain mydomain.net `
                -remoteCluster cluster2 1
                -addIp 10.10.10.2
```

To remove an IP:

```powershell
./remoteIPs.ps1 -vip mycluster `
                -username myuser `
                -domain mydomain.net `
                -remoteCluster cluster2 1
                -removeIp 10.10.10.2
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -remoteCluster: name of remote cluster
* -addIp: (optional) IP address to add
* -removeIp: (optional) IP address to remove
