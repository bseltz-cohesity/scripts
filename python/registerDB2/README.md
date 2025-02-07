# Register Univeral Data Adapter DB2 Protection Source using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script registers a Universal Data Adapter DB2 protection source.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerDB2/registerDB2.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x registerDB2.py
# end download commands
```

## Components

* [registerDB2.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerDB2/registerDB2.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./registerDB2.py -v mycluster \
                 -u myuser \
                 -d mydomain.net \
                 -n myuda1.mydomain.net \
                 -t Other \
                 -p /opt/cohesity/postgres/scripts \
                 -a '--source-name=pguda2.seltzer.net --port=5432 --pg-bin=/usr/pgsql-10/bin' \
                 -au postgres
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

* -n, --hostname: One or more IP or FQDN of protection sources to register (repeat for multiple)
* -p, --scriptdir: (optional) Location of DB2 scripts (default is /opt/cohesity/db2/scripts)
* -kp, --kerberosprincipal: (optional) kerberos principal
* -kt, --kerberoskeytab: (optional) keytab file path
* -kc, --kerberoscache: (optional) kerberos credentials cache path
* -cp, --certificatepath: (optional) Cohesity certificate path
* -dn, --datasourcename: datasource name
* -pu, --protectionusername: (optional) protection username
* -in, --instancename: (optional) instance name
* -pp, --profilepath: profile path
* -ev, --environmentvariables: (optional) e.g. 'ASE_BLOCK_SIZE=65536'
* -la, --logarchive: (optional) Use Cohesity storage for log archival using LOGARCHMETH2
