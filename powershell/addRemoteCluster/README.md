# Add Remote Cluster Replication using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script establishes replication between two Cohesity clusters.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/addRemoteCluster/addRemoteCluster.ps1).content | Out-File addRemoteCluster.ps1; (Get-Content addRemoteCluster.ps1) | Set-Content addRemoteCluster.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [addRemoteCluster.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/addRemoteCluster/addRemoteCluster.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together, then we can run the script.

If not specified, the script will attempt to pair the default storage domains, (e.g. 'DefaultStorageDomain') on both clusters.

```powershell
./addRemoteCluster.ps1 -localVip 192.168.1.198 -localUsername admin -remoteVip 10.1.1.202 -remoteUsername admin
```

```text
Connected!
Connected!
Added replication partnership cohesity1 -> cohesity2
Added replication partnership cohesity2 <- cohesity1
```

## Parameters

* -localVip: Cohesity Cluster to connect to
* -localUsername: Cohesity username
* -localDomain: (optional) Active Directory domain of user (defaults to local)
* -localPassword: (optional) password for local user (default is none)
* -localStorageDomain: (optional) local storage domain or pairing (defaults to DefaultStorageDomain)
* -remoteVip: remote cluster to pair for replication
* -remoteUsername: username to connect to the remote cluster
* -remotePassword: password for remote user (default is none)
* -remoteDomain: (optional) remote user domain name (defaults to local)
* -remoteStorageDomain: (optional) remote storage domain or pairing (defaults to DefaultStorageDomain)
* -remoteAccess: enable remote access
