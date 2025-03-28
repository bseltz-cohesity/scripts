# Generate a VM Recovery Report using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script creates a VM Recovery report.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/vmRecoveryReport/vmRecoveryReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x vmRecoveryReport.py
# end download commands
```

## Components

* vmRecoveryReport.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example
./vmRecoveryReport.py -v mycluster \
                      -u myusername \
                      -d mydomain.net
# end example
```

To specify a recovery task by name:

```bash
# example
./vmRecoveryReport.py -v mycluster \
                      -u myusername \
                      -d mydomain.net \
                      -n Recover_VM_Jan_14_2025_10_11_AM
# end example
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

* -y, --daysback: (optional) default is 7
* -n, --task: (optional) recovery task name (or ID) to include (repeat for multiple)
* -l, --tasklist: (optional) text file of recovery task names (or IDs) to include (one per line)
* -vm, --vmname: (optional) name of VM to include (repeat for multiple)
* -vl, --vmlist: (optional) text file of VM names to include (one per line)
* -f, --outfilename: (optional) default is vmRecoveryReport.csv
