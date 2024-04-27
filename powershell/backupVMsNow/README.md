# Backup a List of VMs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script performs a run now on a list of protected VMs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'backupVMsNow'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [backupVMsNow.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/backupVMsNow/backupVMsNow.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Create a text file containing a list of VMs. Note that these VMs must already be part of an existing protection job. Place all files in a folder together and run the main script like so:

```powershell
./backupVMsNow.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -vmlist ./vmlist.txt `
                    -wait
```

```text
Connected!
Backing up ameTB-centos7 (231-VMs)
Backing up testdev-centos07-BB (231-VMs)
Backing up centos07-BB-res1 (231-VMs)
Backing up SA-BSeltz-CentOS1 (SA-VMs)
Backing up SA-BSeltz-CentOS2 (SA-VMs)
Backing up anoop-centos-1 (TVCenter60-VMs)
Backing up CentOS-EJ (TVCenter60-VMs)
Backing up mracc-linux-05 (TVCenter-VMs2)
Backing up copy-pb-centos01 (TVCenter-VMs2)
Backing up pb-centos01 (TVCenter-VMs2)
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -vmlist: (optional) defaults to ./vmlist.txt
* -wait: (optional) wait for jobs to complete
