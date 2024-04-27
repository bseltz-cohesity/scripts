# Create a View Alias using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script creates a view alias (additional share) in a Cohesity View.

## Download the script

Run these commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/createViewAlias/createViewAlias.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x createViewAlias.py
```

## Components

* [createViewAlias.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/createViewAlias/createViewAlias.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
#example
./createViewAlias.py -v mycluster \
                     -u myusername \
                     -d mydomain.net \
                     -n myview \
                     -a myalias \
                     -p /folder1
#end example
```

## Parameters

* -v, --vip: Cohesity cluster to connect to
* -u, --username: Cohesity username
* -d, --domain: (optional) Active Directory domain (defaults to 'local')
* -n, --viewname: name of new view to create
* -a, --aliasname: name of alias to create
* -f, --folderpath: (optional) path to share (default is /)
