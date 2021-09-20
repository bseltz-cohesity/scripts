# Protect Avid Workspaces Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script protects linux-based AVID proxies.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/avidProxy/avidProxy.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x avidProxy.py
# end download commands
```

## Components

* protectLinux.py: the main powershell script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./avidProxy.py -v mycluster \
               -u myuser \
               -d mydomain.net \
               -j avid-backup \
               -n avidproxy1 \
               -n avidproxy2 \
               -m /mnt/avid \
               -p 'my policy'
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -n, --proxyname: (optional) name of proxy to protect (use multiple times for multiple)
* -l, --proxylist: (optional) text file containing proxy names 9one per line)
* -j, --jobprefix: prefix of job name to create
* -m, --mountpoint: path of expirted avid root (e.g. /mnt/avid)
* -r, --avidroot: (optional) path of avid root if different then mountpoint (e.g. /mnt/avid)
* -s, --showdelimiter: (optional) default is '_' (underscore)
* -p, --policyname: name of protection policy to use for new job (only required for new job)
* -sd, --storagedomain: (optional) name of storage domain to create job in (default is DefaultStorageDomain)
* -tz, --timezone: (optional) time zone for new job (default is US/Eastern)
* -st, --starttime: (optional) start time for new job (default is 21:00)
* -f, --maxlogfilesize: (optional) default is 100000 (bytes)
