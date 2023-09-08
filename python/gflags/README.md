# Get Set and Import gFlags using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script gets, sets and imports gflags.

## Components

* gflags.py: the main python script
* pyhesity.py: the Cohesity python helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/gflags/gflags.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x gflags.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
# example
./gflags.py -v mycluster \
            -u myuser \
            -d mydomain.net \ 
            -s iris \
            -n iris_ui_flags \
            -f 'loginBanner=true' \
            -r 'Enable Banner' \
            -e
# end example
```

## Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username, defaults to local
* -a, --accesscluster: (optional) cluster to connect to when connected to helios
* -k, --useApiKey: (optional) use API key for authentication
* -p, --password: (optional) provide password or API key in clear text
* -s, --servicename: (optional) Name of service
* -n, --flagname: (optional) Name of gflag to set
* -f, --flagvalue: (optional) gflag value to set
* -r, --reason: (optional) reason for setting the flag
* -c, --clear: (optional) reset gflag to default value
* -e, --effectivenow: (optional) make setting effective now (if omitted, gflag changes not effective until service restart(s))
* -i, --importfile: (optional) name of file to import
* -x, --restartservices: (optional) restart services if gflags were set

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

### Installing the Prerequisites

```bash
sudo yum install python-requests
```

or

```bash
sudo easy_install requests
```

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click Settings -> Access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.

If you enter the wrong password, you can re-enter the password like so:

```python
> from pyhesity import *
> apiauth(updatepw=True)
Enter your password: *********************
```
