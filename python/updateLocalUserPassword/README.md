# Update Local User Password using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script updates the password of a local user.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/updateLocalUserPassword/updateLocalUserPassword.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x updateLocalUserPassword.py
# end download commands
```

## Components

* updateLocalUserPassword.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

Update password for user 'otheruser' (will be prompted for the new password):

```bash
./updateLocalUserPassword.py -v mycluster \
                             -u myuser \
                             -d mydomain.net \
                             -lu otheruser
```

Or specify the new password on the commandline:

```bash
./updateLocalUserPassword.py -v mycluster \
                             -u myuser \
                             -d mydomain.net \
                             -lu otheruser \
                             -up Jeromino!
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

* -lu, --localusername: name of local user to update
* -up, --userpassword: (optional) new password (will be prompted if omitted)
