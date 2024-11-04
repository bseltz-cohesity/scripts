# Add Objects and Views to User Access List

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script adds registered objects and views to a user/group restricted access list

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/addObjectsToUserAccessList/addObjectsToUserAccessList.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x addObjectsToUserAccessList.py
# end download commands
```

## Components

* addObjectsToUserAccessList.py: the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example
./addObjectsToUserAccessList.py -v mycluster \
                                -u myuser \
                                -d mydomain.net \
                                -pn myaddomain.net/myaduser \
                                -on myserver.myaddomain.net \
                                -vn myview1
# end example
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication

## Other Parameters

* -on, --objectname: (optional) name of object to add to access list (repeat for multiple)
* -ol, --objectlist: (optional) text file of object names to add to access list (one per line)
* -vn, --viewname: (optional) name of view to add to access list (repeat for multiple)
* -vl, --viewlist: (optional) text file of view names to add to access list (one per line)
* -pn, --principalname: (optional) name of user/group to modify (repeat for multiple)
* -pl, --principallist: (optional) text file of user/group names to modify (one per line)
* -r, --remove: (optional) remove objects/views (default is to add)
