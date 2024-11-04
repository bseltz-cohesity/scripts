# Register Univeral Data Adapter Protection Source using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script registers a Universal Data Adapter protection source.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerUDA/registerUDA.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x registerUDA.py
# end download commands
```

## Components

* [registerUDA.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerUDA/registerUDA.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./registerUDA.py -v mycluster \
                 -u myuser \
                 -d mydomain.net \
                 -n myuda1.mydomain.net \
                 -t Other \
                 -p /opt/cohesity/postgres/scripts \
                 -a '--source-name=pguda2.seltzer.net --port=5432 --pg-bin=/usr/pgsql-10/bin' \
                 -au postgres
```

## Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -mcm, --mcm: (optional) connect through MCM
* -n, --sourcename: One or more IP or FQDN of protection sources to register (repeat for multiple)
* -t, --sourcetype: (optional) Type of UDA database (see list below) default is Other
* -p, --scriptpath: Location of UDA scripts, e.g. /opt/cohesity/postgres/scripts
* -a, --sourceargs: (optional) source registration arguments, e.g. '--source-name=postgres1.mydomain.net'
* -m, --mountview: (optional) false if omitted
* -au, --appusername: (optional) username to connect to app, e.g. postgres
* -ap, --apppassword: (optional)  will be prompted if omitted
* -o, --ostype: (optional) OS type for registration (default is kLinux)

## UDA Source Types

These are the valid UDA source types as of this writing...

* CockroachDB
* DB2
* MySQL
* Other (use this for PostGreSQL and other pre-release plugins)
* SapHana
* SapMaxDB
* SapOracle
* SapSybase
* SapSybaseIQ
* SapASE
