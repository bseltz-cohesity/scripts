# Update vCenter Credentials using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script updates the username and password in a vcenter source registration.

## Components

* [updateVcenterCredentials.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/updateVcenterCredentials/updateVcenterCredentials.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/updateVcenterCredentials/updateVcenterCredentials.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x updateVcenterCredentials.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./updateVcenterCredentials.py -v mycluster \
                              -u myuser \
                              -d mydomain.net \
                              -sn vcenter1.mydomain.net \
                              -su administrator@vcenter.local \
                              -sp mypassword
```

The script takes the following parameters:

* -v, --vip: Cohesity cluster name or IP
* -u, --username: Cohesity Username
* -d, --domain: (optional) Cohesity User Domain (default is local)
* -i, --useApiKey: (optional) use API key for authentication
* -p, --password: (optional) cohesity user password or API key
* -sn, --sourcename: vcenter source name
* -su, --sourceuser: vcenter username
* -sp, --sourcepassword: vcenter password
