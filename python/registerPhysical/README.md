# Register Physical Protection Sources using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script registers physical protection sources.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerPhysical/registerPhysical.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x registerPhysical.py
# end download commands
```

## Components

* [registerPhysical.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerPhysical/registerPhysical.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./registerPhysical.py  -v mycluster \
                       -u myuser \
                       -d mydomain.net \
                       -s myserver1.mydomain.net \
                       -s myserver2.mydomain.net \
                       -l serverlist.txt
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -s, --servername: (optional) name of server to register. Repeat parameter to register multiple servers
* -l, --serverlist: (optional) text file of server names to register (one per line)
* -f, --force: (optional) force register
* -t, --throttle: (optional) throttle network bandwidth to X MB/second
* -r, --reregister: (optional) re-register the server (useful if agent configuration was lost)
