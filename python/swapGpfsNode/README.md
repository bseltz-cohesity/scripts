# Swap GPFS Node Protection using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script replaces a protected GPFS node in a physical file-based protection group.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/swapGpfsNode/swapGpfsNode.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x swapGpfsNode.py
# end download commands
```

## Components

* [swapGpfsNode.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/swapGpfsNode/swapGpfsNode.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To swap out gpfsnode1.mydomain.net with gpfsnode4.mydomain.net:

```bash
./swapGpfsNode.py -v mycluster \
                  -u myuser \
                  -d mydomain.net \
                  -j myjob \
                  -o gpfsnode1.mydomain.net \
                  -n gpfsnode1.mydomain.net
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -j, --jobname: name of the job to add the server to
* -o, --oldname: name of old GPFS node (to stop protecting)
* -n, --newnode: name of new GPFS node (to start protecting)
* -r, --newjobname: (optional) rename job to new name
