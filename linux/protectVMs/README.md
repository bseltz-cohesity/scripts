# Protect VMware VMs for Linux

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a binary tool that protects VMware VMs.

## Download the script

You can download the scripts using the following commands:

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/linux/protectVMs/protectVMs
chmod +x protectVMs
# End download commands
```

## Examples

To create a new protection group:

```bash
./protectVMs -v mycluster \
             -u myuser \
             -d mydomain.net \
             -j 'My Backup Job' \
             -p 'My Policy' \
             -vc myvcenter.mydomain.net \
             -n myvm1 \
             -n myvm2 \
             -n myvm3 \
             -st '21:00' \
             -ei
```

To add VMs to an existing protection group:

```bash
./protectVMs -v mycluster \
             -u myuser \
             -d mydomain.net \
             -j 'My Backup Job' \
             -n myvm1 \
             -n myvm2 \
             -n myvm3
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

## VM Parameters

* -j, --jobname: name of the job to add the server to
* -vc, --vcentername: (optional) name of registered vCenter source
* -n, --vmname: (optional) name of VM to protect (repeat for multiple)
* -l, --vmlist: (optional) text file of VM names to protect (one per line)

## New Job Parameters

* -sd, --storagedomain: (optional) name of storage domain to create job in (default is DefaultStorageDomain)
* -p, --policyname: (optional) name of protection policy to use for new job (only required for new job)
* -tz, --timezone: (optional) time zone for new job (default is US/Eastern)
* -st, --starttime: (optional) start time for new job (default is 21:00)
* -is, --incrementalsla: (optional) incremental SLA minutes (default is 60)
* -fs, --fullsla: (optional) full SLA minutes (default is 120)
* -z, --pause: (optional) pause future runs of new job
* -ei, --enableindexing: (optional) enable indexing
