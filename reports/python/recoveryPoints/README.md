# List Recovery Points Per Protected Object

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script lists available recovery points for every protected object in Cohesity.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/recoveryPoints/recoveryPoints.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x recoveryPoints.py
# end download commands
```

## Components

* recoveryPoints.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example
./recoveryPoints.py -v mycluster -u myusername -d mydomain.net
# end example
```

Connect through Helios, get only Oracle:

```bash
# example
./recoveryPoints.py -c mycluster -e kOracle
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
* -em, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -of, --outfolder: (optional) location to write output CSV file (default is '.')
* -e, --environment: (optional) environment (sql, vmware, oracle, etc) default is None
* -s, --pagesize: (optional) page size per API query (default is 1000)
