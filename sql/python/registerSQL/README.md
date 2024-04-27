# Register SQL Protection Sources using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script registers physical SQL protection sources.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/python/registerSQL/registerSQL.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x registerSQL.py
# end download commands
```

## Components

* [registerSQL.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerSQL/registerSQL.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./registerSQL.ps1 -v mycluster \
                  -u myuser \
                  -d mydomain.net \
                  -s myserver1.mydomain.net \
                  -s myserver2.mydomain.net \
                  -l serverlist.txt
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -s, --servername: (optional) name of server to register. Repeat parameter to register multiple servers
* -l, --serverlist: (optional) text file of server names to register (one per line)
