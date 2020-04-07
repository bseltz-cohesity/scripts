# Update Oracle DB Credentials using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script sets the database username and password for an Oracle protection source.

## Components

* updateOracleDbCredentials.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/oracle/python/updateOracleDbCredentials/updateOracleDbCredentials.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
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

* -v, --vip: Cohesity cluster name or IP
* -u, --username: Cohesity Username
* -d, --domain: Cohesity User Domain
* -s, --oracleserver: name of source oracle server
* -o, --oracleuser: oracle username
* -p, --oraclepwd: oracle user password

