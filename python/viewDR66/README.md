# Disaster Recovery of Cohesity Views using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These python scripts recover replicated views at the DR site. These scripts are appropiate for Cohesity versions 6.6 or later.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewDR66/viewDR.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewDR66/deleteOldViews.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewDR66/protectViews.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x viewDR.py
chmod +x deleteOldViews.py
chmod +x protectViews.py
# end download commands
```

## Components

* [viewDR.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewDR66/viewDR.py): execute view failover/failback tasks
* [deleteOldViews.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewDR66/deleteOldViews.py): delete old views after failover/failback
* [protectViews.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewDR66/protectViews.py): protect views after failover/failback
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

## Common Parameters (for all scripts)

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
* -n, --viewname: (optional) name of view to operate on (repeat for multiple)
* -l, --viewlist: (optional) text file of view names to operate on (one per line)

## viewDR.py Specific Parameters

* -if, --initializefailover: (optional) perform planned failover initialization
* -ff, --finalizefailover: (optional) perform planned failover finalization
* -uf, --unplannedfailover: (optional) perform unplanned failover
* -w, --wait: (optional) wait for failover task completion status

## protectViews.py Specific Parameters

* -p, --policyname: name of protection policy to use for view protection groups

Place the files in a folder together.

## Initial Expected State

You will need to have views on ClusterA, protected using a policy that replicates to ClusterB, and the protection groups should be set to automaticall create the remote view with the same view names.

## Performing an Unplanned Failover

To perform an immediate failover of some views to ClusterB, without any final replication, create a text file views.txt that contains the list of views that you want to failover, one view name per line, and then run the viewDR.py script like so:

```bash
./viewDR.py -v ClusterB \
            -u myuser \
            -d mydomain.net \
            -l views.txt \
            -uf \
            -w
```

Once the failover is complete, proceed to `Deleting Outdated Views` and `Reestablishing Replication` sections below.

## Initiate a Planned Failover

To initiate a planned failover of some views to ClusterB:

```bash
./viewDR.py -v ClusterB \
            -u myuser \
            -d mydomain.net \
            -l views.txt \
            -if
```

After initialization, replication will be performed repeatedly, to get the remote views as up to date as polssible before finalization. After at least one replication, finalization can be performed.

## Finalize a Planned Failover

To finalize a planned failover of views that were previously initiated:

```bash
./viewDR.py -v ClusterB \
            -u myuser \
            -d mydomain.net \
            -l views.txt \
            -ff
```

A final replication will take place, during which the view will be marked as read only on both sides of the replication, ensuring that the views are 100% in sync. After the final replication completes, the views on ClusterB will become live (read write).

## Deleting Outdated Views

Once the views are live on ClusterB, we can delete the old views (which are now marked as read only remote views) from ClusterA:

```bash
./deleteOldViews.py -v ClusterA \
                    -u myuser \
                    -d mydomain.net \
                    -l views.txt
```

## Reestablishing Replication

To start replicating the views back to ClusterA (to ensure multi-site backup as well as in preparation for failback), we can apply a protection policy to the protection group(s) now protecting the views on ClusterB:

```bash
./protectViews.py -v ClusterA \
                  -u myuser \
                  -d mydomain.net \
                  -l views.txt \
                  -p mypolicy
```

## Failback

After replication back to ClusterA has completed at least once, you can simply reverse the process. Perform viewDR steps on ClusterA, delete outdated views on ClusterB, and reeastablish replication on ClusterA.
