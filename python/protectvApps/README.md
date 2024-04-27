# Protect vCloud Director vApps Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script protects all the vApps of a vCloud virtual datacenter.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectvApps/protectvApps.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectvApps.py
# end download commands
```

## Components

* [protectvApps.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectvApps/protectvApps.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./protectvApps.py -v mycluster \
                  -u myuser \
                  -d mydomain.net \
                  -j 'My Backup Job' \
                  -s myvcloud.mydomain.net \
                  -o myorg \
                  -c myvdc \
                  -p mypolicy \
                  -t kvAppTemplate \
                  -n 100
```

## Authentication Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -k, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key

## vCloud Parameters

* -j, --jobname: name of the job to add the server to
* -s, --sourcename: name of registered vCloud source
* -o, --orgname: name of vCloud organization
* -c, --vdcname: name of virtual data center
* -t, --vapptype: (optional) kVirtualApp or kvAppTemplate (defaults to all)
* -n, --numtoprotect: (optional) add this number of vapps (of selected type) to the protection job
* -i, --includeprefix: (optional) only include vapps with this name prefix (e.g. 'cat-') repeat for multiple prefixes (case insensitive)
* -e, --excludeprefix: (optional) exclude vapps with this name prefix (e.g. 'dog-') repeat for multiple prefixes (case insensitive)

## New Job Parameters

* -sd, --storagedomain: (optional) name of storage domain to create job in (default is DefaultStorageDomain)
* -p, --policyname: (optional) name of protection policy to use for new job (only required for new job)
* -tz, --timezone: (optional) time zone for new job (default is US/Eastern)
* -st, --starttime: (optional) start time for new job (default is 21:00)
* -is, --incrementalsla: (optional) incremental SLA minutes (default is 60)
* -fs, --fullsla: (optional) full SLA minutes (default is 120)
