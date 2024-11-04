# Generate Oracle Backup Report using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script generates a report of oracle backups and outputs to a CSV

## Components

* [oracleBackupReport.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/oracleBackupReport/oracleBackupReport.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/oracleBackupReport/oracleBackupReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x oracleBackupReport.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./oracleBackupReport.py -v mycluster \
                        -u myuser \
                        -d mydomain.net
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

* -y, --days: (optional) number of days to include (default is 1)
* -o, --lastrunonly: (optional) only include the last run per job
* -l, --includelogs: (optional) log backups are skippped by default
* -x, --units: (optional) MiB or GiB (default is MiB)
* -n, --numruns: (optional) number of runs to retrieve per API call (default is 100)
* -j, --jobname: (optional) limit report to specific protection group name
* -N, --dbname: (optional) limit report to specific database name
* -U, --dbuuid: (optional) limit report to specific database UUID
