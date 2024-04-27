# Update Oracle Archived Log Deletion using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script updates the number of days to retain Oracle archived logs.

## Components

* [updateOracleLogDeletion.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/updateOracleLogDeletion/updateOracleLogDeletion.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/updateOracleLogDeletion/updateOracleLogDeletion.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x updateOracleLogDeletion.py
# end download commands
```

Place both files in a folder together and run the main script like so:

To update log deletion days an entire server:

```bash
./updateOracleLogDeletion.py -v mycluster \
                             -u myuser \
                             -d mydomain.net \
                             -sn oracle1.mydomain.net \
                             -y 1
```

To update log deletion days for a specific database:

```bash
./updateOracleLogDeletion.py -v mycluster \
                             -u myuser \
                             -d mydomain.net \
                             -sn oracle1.mydomain.net \
                             -dn mydb \
                             -y 1
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

## Other Parameters

* -jn, --jobname: (optional) one or more protection job names (repeat for multiple)
* -jl, --joblist: (optional) text file of job names (one per line)
* -sn, --servername: (optional) one or more server names to update log deletion days (repeat for multiple)
* -sl, --serverlist: (optional) text file of server names to update log deletion days (one per line)
* -dn, --dbname: (optional) one or more database names to update log deletion days (repeat for multiple)
* -dl, --dblist: (optional) text file of database names to update log deletion days (one per line)
* -y, --days: (optional) number of days to retain archived logs (default is 1)
