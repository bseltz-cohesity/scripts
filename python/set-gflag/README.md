# Set a gFlag using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script sets a gflag.

## Components

* set-gflag.py: the main python script
* pyhesity.py: the Cohesity python helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/set-gflag/set-gflag.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/set-gflag/pyhesity.py
chmod +x set-gflag.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
# example
./set-gflag.py -c mycluster -u myuser -d mydomain.net -s iris -f iris_ui_flags -v 'loginBanner=true' -r 'Enable Banner' -e
# end example
```

```text
Connected!
setting flag iris_ui_flags to loginBanner=true
```

## Parameters

* -c, --cluster: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -s, --servicename: Name of service
* -f, --flagname: Name of gflag to set
* -v, --flagvalue: gflag value to set
* -r, --reason: reason for setting the flag
* -e, --effectivenow: make setting effective now

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
