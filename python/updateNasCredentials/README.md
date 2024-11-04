# Update NAS Credentials using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script updates the username and password in a NAS source registration.

## Components

* [updateNasCredentials.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/updateNasCredentials/updateNasCredentials.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/updateNasCredentials/updateNasCredentials.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x updateNasCredentials.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./updateNasCredentials.py -v mycluster \
                          -u myuser \
                          -d mydomain.net \
                          -s mynetapp \
                          -su mysmbusername \
                          -sp mysmbpassword \
                          -sd mysmbdomain.net \
                          -au myapiuser \
                          -ap myapipassword
```

If you only want to update the smb password:

```bash
./updateNasCredentials.py -v mycluster \
                          -u myuser \
                          -d mydomain.net \
                          -s mynetapp \
                          -sp mysmbpassword
```

If you only want to update the api password:

```bash
./updateNasCredentials.py -v mycluster \
                          -u myuser \
                          -d mydomain.net \
                          -s mynetapp \
                          -ap mysmbpassword
```

## Parameters

* -v, --vip: Cohesity cluster name or IP
* -u, --username: Cohesity Username
* -d, --domain: (optional) Cohesity User Domain
* -s, --sourcename: NAS source name
* -su, --smbuser: (optional) smb username
* -sp, --smbpassword: (optional) smb password
* -sd, --smbdomain: (optional) smb domain name
* -au, --apiuser: (optional) api username
* -ap, --apipassword: (optional) api password
