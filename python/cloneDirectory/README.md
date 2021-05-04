# Clone a Cohesity View Directory using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script clones a directory within a view.

## Download the Files

Go to the folder where you want to download the files, then run the following commands:

```bash
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/cloneDirectory/cloneDirectory.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x cloneDirectory.py
```

## Components

* cloneDirectory.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./cloneDirectory.py -v mycluster \
                    -u myusername \
                    -d mydomain.net \
                    -s view1/myFolder \
                    -t view2/newFolder
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -s, --sourcepath: view/path of source folder to copy
* -t, --targetpath: view/path of new folder to create as copy destination

Note: if you use '\' in your paths then the paths must be quoted, like '\\view1\myfolder`
