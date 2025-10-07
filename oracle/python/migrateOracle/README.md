# Migrate an Oracle Database Using Python V2

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script migrates a previously restored Oracle database that was instantly restored but not migrated yet.

## Components

* [migrateOracle.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/migrateOracle/migrateOracle.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/migrateOracle/migrateOracle.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x migrateOracle.py
# end download commands
```

Place both files in a folder together and run the main script like so:

To migrate the database that was restored to oracleprod.mydomain.net/proddb:

```bash
./migrateOracle.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -n oracleprod.mydomain.net/proddb
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -n, --dbname: target server/database to migrate (e.g. oracleprod.mydomain.net/proddb)
* -y, --days: (optional) days back to search (default is 31)
