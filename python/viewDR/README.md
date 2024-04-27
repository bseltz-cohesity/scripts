# Disaster Recovery of Cohesity Views using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These python scripts recover replicated views at the DR site. These scripts are appropiate for Cohesity versions prior to version 6.6 (in 6.6 the failover/failback process is significantly changed). The scripts will still work for 6.6, but there is a better approach for 6.6.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewDR/collectDRviews.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewDR/cloneDRviews.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewDR/deleteDRviews.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x collectDRviews.py
chmod +x cloneDRviews.py
chmod +x deleteDRviews.py
# end download commands
```

## Components

* [collectDRviews.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewDR/collectDRviews.py): collect view metadata from the source cluster
* [cloneDRviews.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewDR/cloneDRviews.py): clone views at target cluster
* [deleteDRviews.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/viewDR/deleteDRviews.py): delete views from source cluster (or target cluster)
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place the files in a folder together.

## Collecting View Metadata with collectDRviews.py

Not all view settings are replicated, so in order to bring all settings across during failover/failback, it's necessary to export the view settings so that they are available when needed. Ideally, the collectDRviews.py script should be run on a schedule (e.g. daily) so that exported view settings are kept up to date.

You can run the collectDRviews.py script like so:

```bash
./collectDRviews.py -v mysourcecluster \
                    -u myuser \
                    -d mydomain.net \
                    -p ./metadata/
```

### Parameters for collectDRviews.py

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) supply password (cached password will be used by default)
* -p, --outpath: path to store view metadata (should be at the DR site so it's available at time of failover)

## Performing View Failover with cloneDRviews.py

At time of failover (or failback) you can run the cloneDRviews.py script, like so.

First, decide whether you which views you wish to failover. You can specify one or more view names on the command line, provide a text file of view names, or specify all views. For example, to failover two views:

```bash
./cloneDRviews.py -v mySourceCluster \
                  -u myuser \
                  -d mydomain.net \
                  -p ./metadata/mySourceCluster \
                  -n view1 \
                  -n view2
```

or create a text file with view names (one per line) and:

```bash
./cloneDRviews.py -v myTargetCluster \
                  -u myuser \
                  -d mydomain.net \
                  -m ./metadata/mySourceCluster \
                  -p 'my replication policy' \
                  -l myviews.txt
```

### Parameters for cloneDRviews.py

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) supply password (cached password will be used by default)
* -m, --metadataPath: path to store view metadata (should be at the DR site so it's available at time of failover)
* -p, --policyName: (optional) name of policy to apply to new protection job for replication back to source cluster
* -n, --viewName: (optional) name of view to failover (repeat for multiple views)
* -l, --viewList: (optional) text file containing view names to failover
* -a, --allViews: (optional) failover all views
* -m, --metadataPath: path to metadata exported by collectDRviews.py
* -s, --snapshotDate: (optional) choose the latest backup from on or before this date (e.g. '2021-10-20 23:59:00')
* -k, --keepRemoteViewName: (optional) cloned view will match the name of the existing remote view (e.g. myview-DR)

## Deleting views with deleteDRviews.py

After a successful failover to the DR cluster, if you have decided to redirect your users to the DR cluster, you will likely want to delete the old views from the source cluster. For example:

```bash
./deleteDRviews.py -v mySourceCluster \
                   -u myuser \
                   -d mydomain.net \
```

By default the script will reference a text file that was generated by the cloneDRviews.py script called clonedViews.txt. This ensures that only views that were successfully cloned at the DR site will be deleted.

### Parameters for deleteDRviews.py

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) supply password (cached password will be used by default)
* -n, --viewName: (optional) name of view to delete (repeat for multiple views)
* -l, --viewList: (optional) text file containing view names to delete (default is clonedViews.txt)
* -x, --deleteSnapshots: (optional) delete existing snapshots (for testing use cases only!!!)

## One Way DR Tests

If you simply want to test DR failover by cloning the views at the DR site, you can:

* Run the collectDRviews.py script to collect the metadata from the source site
* Run the cloneDRviews.py script to clone the views at the DR site (omit the --policyName parameter to skip protecting the new view)
* After completing your testing, run the deleteDRviews.py script to delete the views from the DR site

## End-to-end Failover/Failback Tests

If you want to go all the way and failover the views, bring the users over, replicate and fail back to production, you can:

### Failover

* Run the collectDRviews.py script to collect the metadata from the source site
* Run the cloneDRviews.py script to clone the views at the DR site (include the --policyName parameter to protect the new views and replicate back to the source site)
* Run the deleteDRviews.py script to delete the views from the source site

### Failback

* Complete your testing, and ensure that replication back to the source site is complete and up to date
* Run the cloneDRviews.py script to clone the views back to the source site (include the --policyName parameter to protect the new views and replicate to the DR site)
* Run the deleteDRviews.py script to delete the views from the DR site
