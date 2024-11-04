# Store API Password using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script stores an API password in a shared password file.

## Download the script

Run these commands from a terminal to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/storePasswordInFile/storePasswordInFile.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x storePasswordInFile.py
# End download commands
```

## Components

* [storePasswordInFile.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/storePasswordInFile/storePasswordInFile.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

```bash
./storePasswordInFile.py -v mycluster -u myuser -d mydomain.net -p mypassword
```

## Parameters

* -v, --vip: name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: short username to authenticate to the cluster (default is helios)
* -d, --domain: (optional) active directory domain of user (default is local)
* -p, --password: (optional) will be prompted if omitted
