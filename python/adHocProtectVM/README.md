# Backup New VMs Once using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script temporarily adds VMware VMs to a new (temporary) or existing VM protection group, runs the group and then removes the VMs, to affect an ad hoc backup of the VMs.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/adHocProtectVM/adHocProtectVM.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x adHocProtectVM.py
# End download commands
```

## Components

* [adHocProtectVM.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/adHocProtectVM/adHocProtectVM.py): the main PowerShell script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

To backup VMs using an existing protection group:

```bash
# example
./adHocProtectVM.py -v mycluster \
                    -u myuser \
                    -d mydomain.net \
                    -j 'My Backup Job' \
                    -vn myvm1 \
                    -vn myvm2
# end example
```

To force a source refresh (to discover brand new VMs), add -rs (--refreshsource):

```bash
# example
./adHocProtectVM.py -v mycluster \
                    -u myuser \
                    -d mydomain.net \
                    -j 'My Backup Job' \
                    -vn myvm1 \
                    -vn myvm2 \
                    -rs
# end example
```

To backup VMs using a new (temporary) protection group, we must provide the vCenter name and policy name:

```bash
# example
./adHocProtectVM.py -v mycluster \
                    -u myuser \
                    -d mydomain.net \
                    -vn myvm1 \
                    -vn myvm2 \
                    -vc myVcenter.mydomain.net \
                    -pn 'my policy'
# end example
```

## Authentication Parameters

* -v, --vip: name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: short username to authenticate to the cluster (default is helios)
* -d, --domain: (optional) active directory domain of user (default is local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -mfacode, --mfacode: (optional) Totp code to send for MFA

## Selection Parameters

* -j, --jobname: (optional) name of protection job to run
* -vn, --vmname: (optional) name of VM to backup (repeat this parameter for multiple objects)
* -vl, --vmlist: (optional) text file of VM names to backup (one per line)
* -rs, --refreshsource: (optional) perform source refresh on vCenter to discover new VMs

## New Job Parameters

* -vc, --vcentername: (optional) name of registered vCenter source
* -sd, --storagedomain: (optional) name of storage domain to create job in (default is DefaultStorageDomain)
* -p, --policyname: (optional) name of protection policy to use for new job (only required for new job)
* -ei, --enableindexing: (optional) enable indexing

## Policy Overrides

* -l, --localonly: (optional) skip replicas and archivals
* -nr, --noreplica: (optional) skip replicas
* -na, --noarchive: (optional) skip archives
* -a, --archiveTo: (optional) name of archival target to archive to (defaults to policy settings)
* -ka, --keepArchiveFor: (optional) days to keep in archive (defaults to policy settings)
* -r, --replicateTo: (optional) name of remote cluster to replicate to (defaults to policy settings)
* -kr, --keepReplicaFor: (optional) days to keep replica for (defaults to policy settings)
* -k, --keepLocalFor: (optional) days to keep local snapshot (defaults to policy settings)

Note: -k, --keepLocalFor no longer has any affect in recent releases of 6.6 and later. Policy setting is enforced.

## Timing Parameters

* -s, --sleeptimesecs: (optional) seconds to sleep between status queries (default is 360)
* -swt, --startwaittime: (optional) wait for job run to start (default is 60)
* -rwt, --retrywaittime: (optional) wait to retry API call (default is 300)
* -to, --timeoutsec: (optional) timeout waiting for API response (default is 300)
* -iswt, --interactivestartwaittime: (optional) wait for job run to start when in interactive mode (default is 15)
* -irwt, --interactiveretrywaittime: (optional) wait to retry API call  when in interactive mode (default is 30)
* -n, --waitminutesifrunning: (optional) exit after X minutes if job is already running (default is 60)
* -nrt, --newruntimeoutsecs: (optional) exit after X seconds if new run fails to start (default is 3000)

## Monitoring Parameters

* -int, --interactive: (optional) use quicker interactive wait times
* -pr, --progress: (optional) display percent complete
* -x, --abortifrunning: (optional) exit if job is already running (default is to wait and run after existing run is finished)
* -f, --logfile: (optional) filename to log output
* -debug, --debug: (optional) display verbose error and state messages
* -ex, --extendederrorcodes: (optional) return extended set of exit codes
* -sr, --statusretries: (optional) give up trying to get status update after X tries (default is 30)

## Extended Error Codes

* 0: Successful (no error to report)
* 1: Unsuccessful (backup ended in failure or warning)
* 2: authentication error (failed to authenticate)
* 3: Syntax Error (incorrect command line)
* 4: Timed out waiting for existing run to finish (existing run still running)
* 5: Timed out waiting for new run / status update (failed to get status updates)
* 6: Timed out waiting for new run to appear (new run accepted but not started)
* 7: Timed out getting protection jobs
* 8: Target not in policy not allowed
