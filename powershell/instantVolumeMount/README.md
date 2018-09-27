# Cohesity REST API PowerShell Example - Instant Volume Mount

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to perform an Instant Volume Mount using PowerShell. The script takes a thin-provisioned clone of the latest backup of a server volume and attaches it to a server. 

The script takes the following parameters:

- -vip (DNS or IP of the Cohesity Cluster)
- -username (Cohesity User Name)
- -domain (optional - defaults to 'local')
- -sourceServer (source Server Name)
- -targetServer (optional - Server to attach to, defaults to same as sourceServer)

## Components

* instantVolumeMount.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
.\instantVolumeMount.ps1 -vip mycohesity -username admin -sourceServer server1.mydomain.net -targetServer server2.mydomain.net
Connected!
mounting volumes to server2.mydomain.net...
```
