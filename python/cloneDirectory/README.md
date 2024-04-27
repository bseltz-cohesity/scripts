# Clone a Cohesity View Directory using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script clones a directory within a view.

## Download the Files

Go to the folder where you want to download the files, then run the following commands:

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/cloneDirectory/cloneDirectory.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x cloneDirectory.py
```

## Components

* [cloneDirectory.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/cloneDirectory/cloneDirectory.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./cloneDirectory.py -v mycluster \
                    -u myusername \
                    -d mydomain.net \
                    -s view1/myFolder \
                    -t view2/newFolder
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

* -s, --sourcepath: view/path of source folder to copy
* -t, --targetpath: view/path of new folder to create as copy destination
* -l, --logdir: (optional) path to create log file (default is '.')

Note: if you use '\' in your paths then the paths must be quoted, like '\\view1\myfolder`
