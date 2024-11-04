# Update Oracle DB Credentials using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script sets the database username and password for an Oracle protection source.

## Components

* [updateOracleDbCredentials.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/updateOracleDbCredentials/updateOracleDbCredentials.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/updateOracleDbCredentials/updateOracleDbCredentials.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x updateOracleDbCredentials.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./updateOracleDbCredentials.py -v mycluster \
                               -u myuser \
                               -d mydomain.net \
                               -s oracleprod.mydomain.net \
                               -o backup \
                               -p oracle
```

The script takes the following parameters:

* -v, --vip: name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: short username to authenticate to the cluster (default is helios)
* -d, --domain: (optional) active directory domain of user (default is local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password of API key
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -s, --oracleserver: name of source oracle server
* -o, --oracleuser: oracle username
* -p, --oraclepwd: oracle user password
