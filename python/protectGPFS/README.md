# Add GPFS Filesets to a File-based Protection Job Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script adds GPFS file sets to a file-based protection job.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectGPFS/protectGPFS.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/basic_api/basic_api.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectGPFS.py
# end download commands
```

## Components

* [protectGPFS.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectGPFS/protectGPFS.py): the main python script
* basic_api.py: GPFS REST API helper module
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./protectGPFS.py -v mycohesitycluster \
                 -u mycohesityuser \
                 -d mydomain.net \
                 -g mygpfscluster \
                 -gu mygpfsuser \
                 -gn gpfs-node1.mydomain.net \
                 -j 'GPFS backup' \
                 -p bronze \
                 -f fs1/fileset1 \
                 -i /gpfs/fs1/fileset1/ \
                 -e /gpfs/fs1/fileset1/junk/ \
                 -e /gpfs/fs1/fileset1/trash
```

## Cohesity Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication

## GPFS Authentication Parameters

* -g, --gpfs: DNS or IP of the GPFS cluster administrative endpoint
* -gu, --gpfsuser: username to authenticate to GPFS

## Other Parameters

* -gn, --gpfsnode: (optional) name of GPFS node to protect
* -j, --jobname: name of the job to create/update
* -i, --include: (optional) file path to include (use multiple times for multiple paths)
* -n, --includelist: (optional) a text file full of include paths
* -x, --exclude: (optional) file path to exclude (use multiple times for multiple paths)
* -f, --excludelist: (optional) a text file full of exclude file paths

## New Job Parameters

* -sd, --storagedomain: (optional) name of storage domain to create job in (default is DefaultStorageDomain)
* -p, --policyname: (optional) name of protection policy to use for new job (only required for new job)
* -tz, --timezone: (optional) time zone for new job (default is US/Eastern)
* -st, --starttime: (optional) start time for new job (default is 21:00)
* -is, --incrementalsla: (optional) incremental SLA minutes (default is 60)
* -fs, --fullsla: (optional) full SLA minutes (default is 120)
* -z, --pause: (optional) pause new protection group
* -pr, --prescript: (optional) name of pre script (default is prescript.sh)
* -po, --postscript: (optional) name of post script (default is postscript.sh)
