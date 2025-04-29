# Set Support User Password using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script will set/update the support user password.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/supportUserPassword/supportUserPassword.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x supportUserPassword.py
# end download commands
```

## Components

* [supportUserPassword.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/supportUserPassword/supportUserPassword.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To set the initial password:

```bash
./supportUserPassword.py -v mycluster \
                         -u myusername \
                         -d mydomain.net
```

To update the password

```bash
./supportUserPassword.py -v mycluster \
                         -u myusername \
                         -d mydomain.net \
                         -cp 'Sw0rdF1shJeronim0'
```

To protect specific tables:

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -org, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -noprompt, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -np, --newpassword: (optional) will be prompted if omitted
* -cp, --currentpassword: (optional) required if updating password
* -sudo, --enablesudo: (optional) enable sudo access
