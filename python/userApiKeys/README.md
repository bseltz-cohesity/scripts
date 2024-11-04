# Activate and Deactivate API Keys using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script can list, activate or deactivate API Keys for the specified user.

## Download the script

Run these commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/userApiKeys/userApiKeys.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x userApiKeys.py
```

## Components

* [userApiKeys.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/userApiKeys/userApiKeys.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

List a user's API Keys:

```bash
#example
./userApiKeys.py -v mycluster \
                 -u myusername \
                 -d mydomain.net \
                 -nu someuser \
                 -nd mydomain.net
#end example
```

Deactivate the user's API Keys:

```bash
#example
./userApiKeys.py -v mycluster \
                 -u myusername \
                 -d mydomain.net \
                 -nu someuser \
                 -nd mydomain.net \
                 -x
#end example
```

Activate the user's API Keys:

```bash
#example
./userApiKeys.py -v mycluster \
                 -u myusername \
                 -d mydomain.net \
                 -nu someuser \
                 -nd mydomain.net \
                 -a
#end example
```

## Authentication Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfscode: (optional) send MFA code via email

## Other Parameters

* -nu, --nameofuser: name of user to manage
* -du, --domainofuser: (optional) domain of user to manage (default is 'local')
* -x, --deactivate: (optional) deactivate the user's API Keys
* -a, --activate: (optional) activate the user's API Keys
