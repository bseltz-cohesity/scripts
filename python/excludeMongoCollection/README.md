# Exclude MongoDB Collections Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script excludes MongoDB collections from protection groups where auto-protect is used.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/excludeMongoCollection/excludeMongoCollection.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x excludeMongoCollection.py
# end download commands
```

## Components

* [excludeMongoCollection.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/excludeMongoCollection/excludeMongoCollection.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./excludeMongoCollection.py -v mycluster \
                            -u myuser \
                            -d mydomain.net \
                            -n collection1 \
                            -n collection2
```

By default, the script will exclude the collection(s) from all MongoDB protection groups. Optionally you can narrow the scope to specific jobs using the --jobname and --jooblist parameters.

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -k, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -n, --collectionname: (optional) name of collection to exclude (use multiple times for multiple)
* -c, --collectionlist: (optional) list of collection names in a text file (one per line)
* -j, --jobname: (optional) name of protection group to include (use multiple times for multiple)
* -l, --joblist: (optional) list of protection group names in a text file (one per line)
