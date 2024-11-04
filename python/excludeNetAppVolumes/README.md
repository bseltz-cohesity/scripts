# Exclude NetApp Volumes Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script excludes volumes from protection groups that autoprotect NetApp clusters/SVMs, if the volume name matches one of a list of search strings.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/excludeNetAppVolumes/excludeNetAppVolumes.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x excludeNetAppVolumes.py
# end download commands
```

## Components

* [excludeNetAppVolumes.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/excludeNetAppVolumes/excludeNetAppVolumes.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To exclude all volumes that match the strings 'test' or 'scratch':

```bash
./excludeNetAppVolumes.py -v mycluster \
                          -u myusername \
                          -d mydomain.net \
                          -e test \
                          -e scratch
```

To operate against only specific protection groups, you can use the `-j, --jobname` parameter or the `-f, --joblist` parameter.

To operate against only specific NetApp sources, you can use the `-s, --sourcename` parameter or the `-l, --sourcelist` parameter

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt to update password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to

## Other Parameters

* -e, --exclude: (optional) search string to exclude (repeat for multiple)
* -x, --excludelist: (optional) text file of search strings to exclude (one per line)
* -j, --jobname: (optional) filter on job name (repeat for multiple) default is all jobs
* -f, --joblist: (optional) text file of job names to filter on (one per line) default is all jobs
* -s, --sourcename: (optional) filter on registered source name (repeat for multiple) default is all sources
* -l, --sourcelist: (optional) text file of source names to filter on (one per line) default is all sources
