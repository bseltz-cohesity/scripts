# Unregister Protection Sources Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script unregisters protection sources.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/unregisterSource/unregisterSource.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x unregisterSource.py
# end download commands
```

## Components

* [unregisterSource.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/unregisterSource/unregisterSource.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./unregisterSource.py -v mycluster \
                      -u myuser \
                      -d mydomain.net \
                      -s server1.mydomain.net \
                      -s server2.mydomain.net \
                      -l serverlist.txt
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -n, --sourcename: (optional) name of server to add to the job (use multiple times for multiple)
* -l, --sourcelist: (optional) list of server names in a text file (one per line)
* -s, --sleepseconds: (optional) number of seconds to sleep between retries (default is 30)
* -r, --retries: (optional) number of times to retry (default is 10)
