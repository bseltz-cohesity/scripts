# Protect CCS EC2 VMs Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script protects CCS EC2 VMs.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectCCSEC2VMs/protectCCSEC2VMs.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectCCSEC2VMs.py
# end download commands
```

## Components

* [protectCCSEC2VMs.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/python/protectCCSEC2VMs/protectCCSEC2VMs.py): the main powershell script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To protect one or more VMs

```bash
./protectCCSEC2VMs.py -u myuser \
                               -r us-east-2 \
                               -n myvm1 \
                               -n myvm2 \
                               -p mypolicy \
                               -s myawssource
```

To protect a list of VMs (a text file with one VM name per line):

```bash
./protectCCSEC2VMs.py -u myuser \
                      -r us-east-2 \
                      -l ./vmlist.txt \
                      -p mypolicy \
                      -s myawssource
```

## Parameters

* -u, --username: (optional) username to authenticate to Ccs (used for password storage only)
* -r, --region: Ccs region to use
* -s, --sourcename: name of registered M365 protection source
* -p, --policyname: name of protection policy to use
* -n, --vmname: (optional) VM name to protect (repeat for multiple)
* -l, --vmlist: (optional) text file of VM names to protect (one per line)
* -g, --tagname: (optional) name of tag of vms to protect (repeat for multiple)
* -tz, --timezone: (optional) time zone for new job (default is US/Eastern)
* -st, --starttime: (optional) start time for new job (default is 21:00)
* -is, --incrementalsla: (optional) incremental SLA minutes (default is 60)
* -fs, --fullsla: (optional) full SLA minutes (default is 120)
* -t, --protectiontype: (optional) All, CohesitySnapshot, or AWSSnapshot (default is CohesitySnapshot)
* -b, --bootdiskunly: (optional) only protect the boot disk
* -x, --excludedisk: (optional) disk to excludee.g. /dev/xvdb (repeat for multiple)

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
