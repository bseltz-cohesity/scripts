# Register a vCenter Protection Source using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script registers or updates a vCenter protection source.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerVcenter/registerVcenter.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x registerVcenter.py
# end download commands
```

## Components

* [registerVcenter.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerVcenter/registerVcenter.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./registerVcenter.ps1 -v mycluster \
                      -u myuser \
                      -d mydomain.net \
                      -n myvcenter.mydomain.net \
                      -vu myuser@vsphere.local \
                      -vp myvcenterpassword
```

To specify networks for data transfer:

```bash
./registerVcenter.ps1 -v mycluster \
                      -u myuser \
                      -d mydomain.net \
                      -n myvcenter.mydomain.net \
                      -vu myuser@vsphere.local \
                      -vp myvcenterpassword \
                      -nn 192.168.1.0/24 \
                      -nn 192.168.2.0/24
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

* -vn, --vcentername: hostname or IP of vCenter to register
* -vu, --vcenterusername: username for vCenter access
* -vp, --vcenterpassword: (optional) password for vCenter access (will be prompted if omitted)
* -nn, --networkname: (optional) network cidr for data transfer, e.g. 192.168.1.0/24 (repeat for multiple)
* -nl, --networklist: (optional) text file of network cidrs for data transfer (one per line)
* -nc, --clearnetworks: (optional) clear list of network cidrs for data transfer
* -nr, --removenetworks: (optional) remove spedified cidrs (instead of adding)
* -tu, --trackuuid: (optional) use VM BIOS UUID to track virtual machines
* -ldp, --lowdiskpercent: (optional) auto cancel backups if datastore has less than X percent free (set to 0 to clear)
