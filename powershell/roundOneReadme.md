# Round One Setup Scripts

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Components

* addRemoteCluster.ps1: script to establish replication between two clusters
* cohesityCluster.ps1: multi-cluster api function library
* createProtectionPolicy.ps1: script to create new protection policy
* createVMProtectionJob.ps1: script to create new protection job
* cohesity-api.ps1: Cohesity generic API library

Place the files in a folder together, then we can run the scripts.

First, establish replication. This needs to be done before creating the protection policy.

```powershell
./addRemoteCluster.ps1 -localVip 192.168.1.198 -localUsername admin -remoteVip 10.1.1.202 -remoteUsername admin
```
```text
Connected!
Connected!
Added replication partnership awsce -> BSeltzVE01
Added replication partnership awsce <- BSeltzVE01
```

Next, create the protection policy.

```powershell
./createProtectionPolicy.ps1 -vip mycluster -username admin -policyName mypolicy -daysToKeep 30 -replicateTo myremotecluster
```
```text
Connected!
creating policy mypolicy...
```

Finally, create the protection job. Provide a text file with a list of VM Names to add to the job (e.g. myvms.txt). If not specified, the script will attempt to store the job data in the default storage domain, (e.g. 'DefaultStorageDomain').

```powershell
./createVMProtectionJob.ps1 -vip mycluster -username admin -jobName myjob -policyName mypolicy -vCenterName vcenter.mydomain.net -startTime '23:05' -vmList ./myvms.txt

```
```text
Connected!
creating protection job myjob...
```

These scripts have been intentionally kept simple. We can add functionality when we determine it's required.