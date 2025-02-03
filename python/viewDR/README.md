# Disaster Recovery of Cohesity Views using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script performs a failover of Cohesity views.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewDR/viewDR.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x viewDR.py
# end download commands
```

## Components

* [viewDR.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewDR66/viewDR.py): execute view failover/failback tasks
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -n, --viewname: (optional) name of view to operate on (repeat for multiple)
* -l, --viewlist: (optional) text file of view names to operate on (one per line)
* -if, --initializefailover: (optional) perform planned failover initialization
* -ff, --finalizefailover: (optional) perform planned failover finalization
* -uf, --unplannedfailover: (optional) perform unplanned failover
* -w, --wait: (optional) wait for failover task completion status
* -s, --sleeptimesecs: (optional) seconds to sleep between status updates (default is 30)

## Initial Expected State

You will need to have views on ClusterA, protected using a policy that replicates to ClusterB, and the protection groups should be set to automatically create the remote view with the same view names.

## Performing an Unplanned Failover

To perform an immediate failover of some views to ClusterB, without any final replication, create a text file views.txt that contains the list of views that you want to failover, one view name per line, and then run the viewDR.py script like so:

```bash
./viewDR.py -v ClusterB \
            -u myuser \
            -d mydomain.net \
            -n myview1 -n myview2 \
            -uf \
            -w
```

or using a text file of view names:

```bash
./viewDR.py -v ClusterB \
            -u myuser \
            -d mydomain.net \
            -l views.txt \
            -uf \
            -w
```

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

## Failback

After replication back to ClusterA has completed at least once, you can simply reverse the process.
