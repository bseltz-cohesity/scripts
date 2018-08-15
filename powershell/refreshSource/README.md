# Cohesity REST API PowerShell Example - Refresh a Protection Source

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to perform a refresh operation on a protection source. The prime example of where this is useful is if a new virtual machine is created on VMware (or other hypervisor) and you want Cohesity to recognize the new VM. Refresh is automatic on a schedule, but a manual refresh can be executed to speed up the process.
The script takes the following parameters:

- -vip (DNS or IP of the Cohesity Cluster)
- -username (Cohesity User Name)
- -domain (optional - defaults to 'local')
- -source (name of the source to refresh)

## Components

* refreshSource.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./refreshSource.ps1 -vip mycluster -username admin -source myVcenter

Connected!

Refreshing myVcenter...
```
