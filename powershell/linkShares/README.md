# Link Shares to Local Directory using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script creates symbolic links to file shares on a remote computer and includes them in a physical protection job.

## Download the scripts

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/linkShares/linkSharesMaster.ps1).content | Out-File linkSharesMaster.ps1; (Get-Content linkSharesMaster.ps1) | Set-Content linkSharesMaster.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/linkShares/linkSharesProxy.ps1).content | Out-File linkSharesProxy.ps1; (Get-Content linkSharesProxy.ps1) | Set-Content linkSharesProxy.ps1
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/linkShares/linkSharesStatus.json).content | Out-File linkSharesStatus.json; (Get-Content linkSharesStatus.json) | Set-Content linkSharesStatus.json
(Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [linkSharesMaster.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/linkShares/linkSharesMaster.ps1): the main powershell script (Master role)
* [linkSharesProxy.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/linkShares/linkSharesProxy.ps1): the main powershell script (Proxy role)
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module
* [linkSharesStatus.json](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/linkShares/linkSharesStatus.json): the shared config file

## Setup

Place the linkSharesStatus.json file somewhere where it can be reached via UNC path, like: \\\\myserver\myshare\linkSharesStatus.json

## Proxy Role

Place the linkSharesProxy.ps1 and the cohesity-api.ps1 files on each proxy computer and run the script like so:

```powershell
.\linkSharesProxy.ps1 -vip mycluster `
                      -username myusername `
                      -domain mydomain.net `
                      -jobName 'my job name' `
                      -nas mynas `
                      -localDirectory C:\Cohesity\ `
                      -statusFile \\myserver\myshare\linkSharesStatus.json
```

## Master Role

Place the linkSharesMaster.ps1 file on a server where ssh.exe is available so that it can reach the linux server where the workspace list is available.

Run the master script like:

```powershell
.\linkSharesMaster.ps1 -linuxUser myuser `
                       -linuxHost myhost `
                       -linuxPath /home/myuser/mydir `
                       -statusFile \\myserver\myshare\linkSharesStatus.json
```

The master will distribute shows and workspaces among the proxies. The next time the proxy scripts run, the proxy will create the links and add them to the protection job.
