# Update CCS RDS Credentials using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script script updates RDS credentials in CCS.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/python/updateCcsRdsCredentials/updateCcsRdsCredentials.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x updateCcsRdsCredentials.py
# end download commands
```

## Components

* [updateCcsRdsCredentials.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/python/updateCcsRdsCredentials/updateCcsRdsCredentials.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To see the list of RDS instances:

```bash
./updateCcsRdsCredentials.py -sn 220923520471
```

To filter by type:

```bash
./updateCcsRdsCredentials.py -sn 220923520471 \
                             -t kAuroraCluster
```

To filter by database engine:

```bash
./updateCcsRdsCredentials.py -sn 220923520471 \
                             -d aurora-postgresql15.4
```

To filter by name:

```bash
./updateCcsRdsCredentials.py -sn 220923520471 \
                             -n db1 -n db2
```

To update credentials:

```bash
./updateCcsRdsCredentials.py -sn 220923520471 \
                             -n db1 -n db2 \
                             -x \
                             -t iam
                             -ru myuser
```

## Basic Parameters

* -u, --username: (optional) username to authenticate to Ccs (used for password storage only)
* -pwd, --password: (optional) API key for authentication
* -np, --noprompt: (optional) do not prompt for API key, exit if not authenticated
* -sn, --sourcename: name of registered AWS source

## Filter Parameters

* -n, --rdsname: (optional) filter by RDS instance names (comma separated)
* -l, --rdslist: (optional) text file of RDS instance names to filter by (one per line)
* -t --rdstype: (optional) filter by RDS instance type (kAuroraCluster or kRDSInstance)
* -d, --dbrngine: (optional) filter by database engine

## Update Parameters

* -x, --update: (optional) perform credential update
* -a, --authtype: (optional) 'credentials', 'iam' or 'kerberos' (default is 'credentials')
* -ru, --rdsuser: (optional) username for credential update
* -rp, --rdspassword: (optional) password for credential update (required for credentials and kerberos)
* -rn, --realmname: (optional) kerberos realm name for credential update (required for kerberos)
* -rd, --realmdnsaddress: (optional) kerberos DNS address for credential update (required for kerberos)

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
