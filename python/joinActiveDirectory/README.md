# Join an Active Directory using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script will join the Cohesity cluster to an Active Directory domain.

## Components

* [joinActiveDirectory.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/joinActiveDirectory/joinActiveDirectory.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/joinActiveDirectory/joinActiveDirectory.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x joinActiveDirectory.py
# end download commands
```

```bash
./joinActiveDirectory.py -v mycluster \
                         -u myuser \
                         -d local \
                         -ad mydomain.net \
                         -au myaduser \
                         -cn mycluster \
                         -ou Computers
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -ad, --addomain: FQDN of active directory to join
* -au, --adusername: active directory username
* -ap, --adpassword: (optional) will be prompted if omitted
* -cn, --computername: name of computer account to create/use
* -ou, --container: (optional) canonical name of container/OU for computer account (default is Computers)
* -nb, --netbiosname: (optional) netbios name of active directory (default is None)
* -ex, --useexistingaccount: (optional) use existing computer account

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
