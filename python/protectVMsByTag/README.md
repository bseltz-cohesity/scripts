# Auto-protect VMs by Tag Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script auto-protects VMware VMs by tag.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectVMsByTag/protectVMsByTag.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectVMsByTag.py
# end download commands
```

## Components

* [protectVMsByTag.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectVMsByTag/protectVMsByTag.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./protectVMsByTag.py -v mycluster \
                     -u myuser \
                     -d mydomain.net \
                     -j 'My Backup Job' \
                     -vc myvcenter.mydomain.net \
                     -i mytag1 \
                     -i mytag2 \
                     -e mytag3
```

## Authentication Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -k, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key

## VM Parameters

* -j, --jobname: name of the job to add the server to
* -vc, --vcentername: name of registered vCloud source
* -i, --includetag: include tag (repeat for multiple tags)
* -e, --excludetag: exclude tag (repeat for multiple tags)

## New Job Parameters

* -sd, --storagedomain: (optional) name of storage domain to create job in (default is DefaultStorageDomain)
* -p, --policyname: (optional) name of protection policy to use for new job (only required for new job)
* -tz, --timezone: (optional) time zone for new job (default is US/Eastern)
* -st, --starttime: (optional) start time for new job (default is 21:00)
* -is, --incrementalsla: (optional) incremental SLA minutes (default is 60)
* -fs, --fullsla: (optional) full SLA minutes (default is 120)
* -z, --pause: (optional) pause future runs of new job
* -a, --appconsistent: (optional) quiesce VMs during backup

## Tag Logic

When multiple tags are specified, these are combined (logical AND), meaning that a VM must have all specified tags to be included (or excluded).

To achieve a logical OR, simply run the script again with different tags, and those tags will be appended to the list of tag selections.
