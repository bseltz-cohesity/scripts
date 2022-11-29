# Protect Avid Workspaces Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script protects linux-based AVID proxies.

## Setup an AVID Proxy

These are the steps to setup an AVID proxy. An AVID proxy is a Linux VM (or physical host) running the AVID client for Linux, that will mount the AVID shares and re-export them over NFS, so that Cohesity can protect them using a Generic NAS protection group.

This has been tested using CentOS 7.

## How Many Proxies Do I Need

This will depend on the size of your AVID estate, the average daily change rate, and the duration of your nightly backup window. During testing we found that backup throughput was good, and Cohesity performs incremental-forever backups, so on a nightly basis, only new and changed files are backed up. It's conceivable that only one proxy is required, however the avidProxy.py script can distribute backups across multiple proxies, so it is recommended that at least two proxies are used so that you can see the distributed behavoir of the script.

If backup jobs begin to run close to the full nightly backup window, you can add another proxy, and new shows will be added to the new proxy until the number of shows is balanced across proxies.

## Install the Avid Client

Install the AVID client for Linux, and mount the AVID file system to some location, e.e. /mnt/avid

## Install Required Components

We will install NFS server as well as the python requests module.

```bash
yum install python-requests nfs-utils
```

Note: you may need to select the python3-requests module if python 3 is the only available version of python.

## Open NFS Firewall Ports

```bash
firewall-cmd --permanent --zone=public --add-service=nfs
firewall-cmd --permanent --zone=public --add-service=mountd
firewall-cmd --permanent --zone=public --add-service=rpc-bind
firewall-cmd --reload
```

## Add NFS Export

Edit the /etc/exports file and add something like the following:

```bash
/mnt/avid1 192.168.0.0/16(rw,no_root_squash,fsid=1)
/mnt/avid2 192.168.0.0/16(rw,no_root_squash,fsid=2)
/mnt/avid3 192.168.0.0/16(rw,no_root_squash,fsid=3)
```

Note that the fsid must be unique on this host. All proxies should have the same exports.

## Restart the NFS Services

```bash
systemctl restart nfs-server
systemctl stop nfs-server
systemctl start nfs-server
systemctl status nfs-server
```

## Download the AVID Proxy Python Script

```bash
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/avidProxy/avidProxy.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x avidProxy.py
```

## Running the Script

Before running the script, repeat the instructions above for all AVID proxies that you want to setup. Make sure your Cohesity cluster can resolve the names of these proxies, either via DNS entries or host mappings, then we can determine the command line to use to run the script, for example:

```bash
./avidProxy.py -v mycluster \
               -u myuser \
               -d mydomain.net \
               -j avid-backup \
               -n avidproxy1 \
               -n avidproxy2 \
               -m /mnt/avid1 \
               -m /mnt/avid2 \
               -m /mnt/avid3 \
               -p 'my policy'
```

When the script is run the first time, you will be prompted for the password for the Cohesity user. This password will be stored for later use so the script can be run unattended.

The above command line will register the two AVID proxies as Generic NAS protection sources and protect them using two protection groups. The shows in the AVID filesystem will be distributed across the two protection groups, so that backup data will stream through both proxies in a relatively balanced way.

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -pn, --proxyname: (optional) name of proxy to protect (use multiple times for multiple)
* -pl, --proxylist: (optional) text file containing proxy names (one per line)
* -j, --jobprefix: prefix of job name to create
* -mp, --mountpoint: (optional) path of exported avid root (e.g. /mnt/avid) (repeat for multiple)
* -ml, --mountlist: (optional) text file of mount points (one per line)
* -s, --showdelimiter: (optional) default is '_' (underscore)
* -p, --policyname: name of protection policy to use for new job (only required for new job)
* -sd, --storagedomain: (optional) name of storage domain to create job in (default is DefaultStorageDomain)
* -tz, --timezone: (optional) time zone for new job (default is US/Eastern)
* -st, --starttime: (optional) start time for new job (default is 21:00)
* -f, --maxlogfilesize: (optional) default is 100000 (bytes)
