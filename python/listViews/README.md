# List Views using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script lists views on Cohesity

## Download the script

Run these commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/listViews/listViews.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x listViews.py
```

## Components

* listViews.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
#example
./listViews.py -v mycluster \
               -u myusername \
               -d mydomain.net
#end example
```

or to produce detailed output:

```bash
#example
./listViews.py -v mycluster \
               -u myusername \
               -d mydomain.net \
               -s \
               -x MiB
#end example
```

## Parameters

* -v, --vip: Cohesity cluster to connect to
* -u, --username: Cohesity username
* -d, --domain: (optional) Active Directory domain (defaults to 'local')
* -n, --name: (optional) Show specified view only
* -s, --showsettings: (optional) prodice detailed output
* -x, --units: (optional) show values in GiB or MiB (default is GiB)
