# Onboard AD User into Cohesity

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script creates a Cohesity principal for an Active Directory user.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/onboardADUser/onboardADUser.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x onboardADUser.py
# end download commands
```

## Components

* [onboardADUser.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/onboardADUser/onboardADUser.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./onboardADUser.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -n myaduser \
                   -a myaddomain.net \
                   -g
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -n, --aduser: name of AD user to onboard (repeat for multiple)
* -l, --aduserlist: text file of AD users to onboard (one per line)
* -a, --addomain: domain of AD user to onboard
* -desc: --description: (optional) description for user
* -keyname, --keyname: (optional) name for API key(default is aduser-key)
* -r, --role: (optional) Cohesity role to grant to user (default is 'COHESITY_VIEWER')
* -g, --generateApiKey: (optional) generate new API key for user
* -s, --storeApiKey: (optional) store new API key in local password storage
* -o, --overwrite: (optional) overwrite existing API key

## Note

If more than one AD user is specified and `-g` is used, a text file apikeys.txt will be created to record the user's new API keys.
