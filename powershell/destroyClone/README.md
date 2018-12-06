# Destroy Clone Using PowerShell Example

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to tear down a cloned SQLDB, VM, or View.  

## Components

* destroyClone.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./destroy-Clone.ps1 -vip mycluster -username admin -cloneType sql -dbName cohesitydb-test -dbServer sqldev01                                                                                                    
Connected!
tearing down SQLDB: cohesitydb-test from sqldev01...
```


