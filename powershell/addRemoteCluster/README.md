# Add Remote Cluster Replication using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script established replication between two Cohesity clusters.

## Components

* addRemoteCluster.ps1: the main powershell script
* cohesityCluster.ps1: the multi-cluster Cohesity REST API helper module

Place the files in a folder together, then we can run the script.

If not specified, the script will attempt to pair the default storage domain, (e.g. 'DefaultStorageDomain').

```powershell
./addRemoteCluster.ps1 -localVip 192.168.1.198 -localUsername admin -remoteVip 10.1.1.202 -remoteUsername admin
```
```text
Connected!
Connected!
Added replication partnership awsce -> BSeltzVE01
Added replication partnership awsce <- BSeltzVE01
```

