# Register New MongoDB Protection Source using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script registers new MongoDB protection sources.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerMongoDB/registerMongoDB.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x registerMongoDB.py
# end download commands
```

## Components

* [registerMongoDB.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerMongoDB/registerMongoDB.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./registerMongoDB.py -v mycluster \
                     -u myusername \
                     -d mydomain.net \
                     -n mongo1.mydomain.net:27017
```

or if you want to register a source with multiple seeds:

```bash
./registerMongoDB.py -v mycluster \
                     -u myusername \
                     -d mydomain.net \
                     -n 'mongo1.mydomain.net:27017, mongo2.mydomain.net:27017'
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

* -n, --servername: name of server:port to register (repeat for multiple)
* -l, --serverlist: text file containing list of servers to register (one per line)
* -t, --authtype: (optional) one of NONE, SCRAM, LDAP, or KERBEROS (default is NONE)
* -au --authusername: (optional) username for SCRAM or LDAP authentication
* -ap, --authpassword: (optional) password for SCRAM or LDAP authentication
* -ad, --authdatabase: (optional) database for SCRAM or LDAP authentication
* -kp, --krbprincipal: (optional) principal for KERBEROS authentication
* -st, --secondarytag: (optional) secondary node tag
* -ssl, --usessl: (optional) require SSL
* -sec, --usesecondary: (optional) backup from ssecondary node
