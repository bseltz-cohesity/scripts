# Create a VM Protection Job using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script creates a new VM Potection Job.

## Components

* createVMProtectionJob.ps1: the main powershell script
* cohesityCluster.ps1: the multi-cluster Cohesity REST API helper module

Place the files in a folder together, then we can run the script.

If not specified, the script will attempt to store the job dat in the default storage domain, (e.g. 'DefaultStorageDomain').

```powershell
./createVMProtectionJob.ps1 -vip mycluster -username admin -jobName myjob -policyName mypolicy -vCenterName vcenter.mydomain.net -startTime '23:05' -vmList ./myvms.txt

```
```text
Connected!
creating protection job myjob...
```

