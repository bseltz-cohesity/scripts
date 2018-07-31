# Cohesity Agent Versions

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script lists the version of the installed Cohesity agent on every physical server registered on the cluster

## Components

* agentVersions.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./agentVersions.ps1 -vip mycluster -username admin -domain local
```
