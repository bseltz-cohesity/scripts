# Manage Policies Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script lists or modifies protection policies. The script is a work in progress and currently performs the following acttions:

* List Policies: shows local, replica and archival frequencies and retentions
* Create a policy with a base schedule and retention
* Delete a policy
* Edit base schedule and retention
* Add or edit an extended retention
* Delete an extended retention
* Add or edit a log backup
* Add a Replica
* Delete a Replica
* Add an Archive Target
* Delete an Archive Target
* Edit Retry setting

Other features will be considered upon request.

Note: this script is written for Cohesity 6.5.1 and later.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/policyTool/policyTool.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/policyTool/policyTool7.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x policyTool.py
# end download commands
```

## Components

* [policyTool.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/policyTool/policyTool.py): the main python script (for versions of Cohesity before 7.1)
* [policyTool7.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/policyTool/policyTool.py): the main python script (for versions of Cohesity 7.1 or later)
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To list policies:

```bash
./policyTool.py -v mycluster \
                -u myuser \
                -d mydomain.net
```

To list a specific policy:

```bash
./policyTool.py -v mycluster \
                -u myuser \
                -d mydomain.net \
                -p 'my policy'
```

To add a replica that replicates after every run with 31 day retention:

```bash
./policyTool.py -v mycluster \
                -u myuser \
                -d mydomain.net \
                -p 'my policy' \
                -a addreplica \
                -n myremotecluster \
                -r 31
```

To add a replica that replicates every two weeks with 3 month retention:

```bash
./policyTool.py -v mycluster \
                -u myuser \
                -d mydomain.net \
                -p 'my policy' \
                -a addreplica \
                -n myremotecluster \
                -f 2 \
                -fu weeks \
                -r 3 \
                -ru months
```

To delete that replica:

```bash
./policyTool.py -v mycluster \
                -u myuser \
                -d mydomain.net \
                -p 'my policy' \
                -a deletereplica \
                -n myremotecluster \
                -f 2 \
                -fu weeks 
```

To delete all replicas for a remote cluster:

```bash
./policyTool.py -v mycluster \
                -u myuser \
                -d mydomain.net \
                -p 'my policy' \
                -a deletereplica \
                -n myremotecluster \
                -all
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -k, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -p, --policyname: (optional) name of policy to focus on
* -n, --targetname: (optional) name of remote cluster or archive target
* -f, --frequency: (optional) number of frequency units for schedule (default is 1)
* -fu, --frequencyunit: (optional) default is every run
* -r, --retention: (optional) number of retention units
* -t, --retries: (optional) number of times to retry failed backups (default is 3)
* -m, --retryminutes: (optional) number of minutes to wait between retries (default is 5)
* -ru, --retentionunit: (optional) default is days
* -ld, --lockduration: (optional) number of lock units
* -lu, --lockunit: (optional) default is days
* -a, --action: (optional) see below (default is list)
* -all, --all: (optional) delete all entries for the specified target
* -aq, --addquiettime: (optional) add quiet time (see format below) repeat for multiple
* -rq, --removequiettime: (optional) remove quiet time (see format below) repeat for multiple

## Addition Parameters for policyTool7

* -dow, --dayofweek: (optional) day of the week for daily or monthly elements (repeat for multiple)
* -wom, --weekofmonth: (optional) week of the month, e.g. First, Second, Third, Fourth, Last
* -dom, --dayofmonth: (optional) day of the month, e.g. 1
* -doy, --dayofyear: (optional) First or Last

## Actions

* list: show policy settings (default)
* delete: delete a policy
* create: create a new policy with a base schedule
* edit: edit base schedule and retention
* editretries: edit retry settings
* addextension: add or edit an extended retention
* deleteextension: delete an extended retention
* logbackup: add or edit log backup schedule
* addreplica: add or edit a replication
* deletereplica: delete a replication
* addarchive: add or edit an archive
* deletearchive: delete an archive
* addfull: add full backup
* deletefull: delete full backup

## Quiet Time Format

Quite times can be entered as a quoted string in the format:

`'days;startTime;endTime'`

For example:

`'Saturday,Sunday;00:00;02:30'`

To specify all days of the week, use 'All':

`'All;00:00;02:30'`
