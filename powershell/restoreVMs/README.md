# Restore a List of VMs using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script restores a list of protected VMs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/restoreVMs/restoreVMs.ps1).content | Out-File restoreVMs.ps1; (Get-Content restoreVMs.ps1) | Set-Content restoreVMs.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/restoreVMs/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* restoreVMs.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Create a text file containing a list of VMs. Note that these VMs must already be part of an existing protection job. Place all files in a folder together and run the main script like so:

```powershell
./restoreVMs.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -vmlist ./vmlist.txt `
                    -prefix test `
                    -poweron `
                    -wait
```

```text
Connected!
restoring ameTB-centos7
restoring testdev-centos07-BB
restoring centos07-BB-res1
restoring SA-BSeltz-CentOS1
restoring SA-BSeltz-CentOS2
restoring anoop-centos-1
restoring CentOS-EJ
restoring mracc-linux-05
restoring copy-pb-centos01
restoring pb-centos01
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -vmlist: (optional) defaults to ./vmlist.txt
* -prefix: (optional) add a prefix to the VM names during restore
* -poweron: (optional) power on the VMs during restore (default is false)
* -wait: (optional) wait for restore tasks to complete
* -recoverDate: (optional) use latest point in time at or before date, e.g. '2019-10-01 23:30:00'
