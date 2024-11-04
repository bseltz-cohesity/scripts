# Add Local User using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script adds a local user.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/addLocalUser/addLocalUser.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x addLocalUser.py
# end download commands
```

## Components

* addLocalUser.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

Create a user 'newuser' (will be prompted for the new password):

```bash
./addLocalUser.py -v mycluster \
                  -u myuser \
                  -d mydomain.net \
                  -n newuser \
                  -e newuser@mydomain.net
```

Or specify the new password on the commandline:

```bash
./addLocalUser.py -v mycluster \
                  -u myuser \
                  -d mydomain.net \
                  -n newuser \
                  -e newuser@mydomain.net \
                  -np Sw0rdFish!
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key

## Other Parameters

* -n, --newusername: user name for local user
* -e, --emailaddress: email address for local user
* -np, --newpassword: (optional) password for local user (will be prompted if omitted)
* -m, --moniker: (optional) API key name suffix (default is 'key')
* -r, --role: (optional) role to grant to user (default is 'COHESITY_VIEWER')
* -g, --generateApiKey: (optional) generate new API key
* -s, --storeApiKey: (optional) store API key in file
* -o, --overwrite: (optional) overwrite existing API key
* -x, --disablemfa: (optional) exempt user from MFA
