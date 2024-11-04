# Destroy Clone Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to tear down a cloned SQL DB, Oracle DB, VM, or View.  

## Components

* [destroyClone.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/destroyClone/destroyClone.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/destroyClone/destroyClone.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x destroyClone.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./destroyClone.py -v mycluster -u myuser -d mydomain.net -o devdb -s oracle1.mydomain.net -t oracle -w
```

## Parameters

* -v, --vip: name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: short username to authenticate to the cluster (default is helios)
* -d, --domain: (optional) active directory domain of user (default is local)
* -k, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -t, --clonetype: vm, sql, oracle, view, or oracle_view
* -o, --objectname: name of vm, database or view
* -s, --server: name of database server (required when tearing down a database)
* -i, --instance: name of SQL Server instance (defaults to MSSQLSERVER)
* -w, --wait: wait for completion
