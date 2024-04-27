# Update Firewall Rules using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script adds/removes CIDR addresses from the firewall allow list of the specified service profile.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/firewallTool/firewallTool.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x firewallTool.py
# end download commands
```

## Components

* [firewallTool.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/firewallTool/firewallTool.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To display the allow list for a profile (e.g. SNMP):

```bash
./firewallTool.py -v mycluster \
                  -u myusername \
                  -d mydomain.net \
                  -p SNMP
```

To add an entry to the allow list for the SNMP profile:

```bash
./firewallTool.py -v mycluster \
                  -u myusername \
                  -d mydomain.net \
                  -p SNMP \
                  -ip 172.31.0.0/16 \
                  -a
```

To remove an entry from the allow list for the SNMP profile:

```bash
./firewallTool.py -v mycluster \
                  -u myusername \
                  -d mydomain.net \
                  -p SNMP \
                  -ip 172.31.0.0/16 \
                  -r
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

## Firewall Parameters

* -ip, --ip: (optional) CIDR to add or remove (repeat for multiple)
* -l, --iplist: (optional) text file of CIDRs to add or remove (one per line)
* -a, --addentry: (optional) add CIDRs to allow list
* -r, --removeentry: (optional) remove CIDRs from allow list
* -p, --profile: name of profile to modify. Valid profile names are 'Management', 'SNMP', 'S3', 'Data Protection', 'Replication', 'SSH', 'SMB', 'NFS'
