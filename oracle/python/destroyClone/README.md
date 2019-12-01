# Destroy Clone Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to tear down a cloned SQL DB, Oracle DB, VM, or View.  

## Components

* destroyClone.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/oracle/python/destroyClone/destroyClone.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x destroyClone.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./destroyClone.py -v mycluster -u myuser -d mydomain.net -o devdb -s oracle1.mydomain.net -t oracle -w
```

## Parameters

* -v, --vip: Cohesity cluster name or IP
* -u, --username: Cohesity Username
* -d, --domain: Cohesity User Domain
* -t, --clonetype: vm, sql, oracle or view
* -o, --objectname: name of vm, database or view
* -s, --server: name of database server (required when tearing down a database)
* -i, --instance: name of SQL Server instance (defaults to MSSQLSERVER)
* -w, --wait: wait for completion
