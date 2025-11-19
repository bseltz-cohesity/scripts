# Register Oracle Protection Sources using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script registers Oracle protection sources.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/registerOracle/registerOracle.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x registerOracle.py
# end download commands
```

## Components

* [registerOracle.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/registerOracle/registerOracle.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./registerOracle.ps1 -v mycluster \
                       -u myuser \
                       -d mydomain.net \
                       -s myserver1.mydomain.net \
                       -s myserver2.mydomain.net \
                       -l serverlist.txt
```

## Parameters

* -v, --vip: (optional) name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) short username to authenticate to the cluster (default is helios)
* -d, --domain: (optional) active directory domain of user (default is local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password of API key
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -s, --servername: (optional) name of server to register. Repeat parameter to register multiple servers
* -l, --serverlist: (optional) text file of server names to register (one per line)
* -o, --oraclecluster: (optional) use this switch when registering an Oracle cluster
