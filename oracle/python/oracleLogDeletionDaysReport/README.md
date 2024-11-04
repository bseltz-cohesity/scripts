# Report Oracle Archived Log Deletion Settings using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script reports the number of days to retain Oracle archived logs for each protected Oracle database.

## Components

* [oracleLogDeletionDaysReport.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/oracleLogDeletionDaysReport/oracleLogDeletionDaysReport.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/oracleLogDeletionDaysReport/oracleLogDeletionDaysReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x oracleLogDeletionDaysReport.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./oracleLogDeletionDaysReport.py -v mycluster \
                                 -u myuser \
                                 -d mydomain.net
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
* -e --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -of, --outfolder: (optional) folder to output CSV (default is '.')
