# Link Shares to Local Directory using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script creates symbolic links to file shares on a remote computer and includes them in a pphysical protection job.

## Download the scripts

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/linkShares/linkShares.ps1).content | Out-File linkShares.ps1; (Get-Content linkShares.ps1) | Set-Content linkShares.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/linkShares/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* linkShares.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together on the proxy computer using the download commands above, then, run the linkShares.ps1 script like so:

```powershell
# example command
.\linkShares.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName myjob -remoteComputer fileserver.mydomain.net -proxyComputer protectedcomputer.mydomain.net -localDirectory c:\Cohesity
# end example command
```

## Parameters

* -vip: the Cohesity cluster to connect to
* -username: the cohesity user to login with
* -domain: domain of the Cohesity user (defaults to local)
* -jobName: name of protection job to update
* -proxyComputer: the local computer on which to create the links
* -remoteComputer: the remote computer hosting the file shares
* -localDirectory: the parent path in which to create the links
