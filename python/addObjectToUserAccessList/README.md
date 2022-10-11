# Add Objects and Views to User Access List

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script adds registered objects and views to a user's restricted access list

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/addObjectsToUserAccessList/addObjectsToUserAccessList.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x addObjectsToUserAccessList.py
# end download commands
```

## Components

* addObjectsToUserAccessList.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./addObjectsToUserAccessList.py -v mycluster \
                                -u myuser \
                                -d mydomain.net \
                                -n myaduser \
                                -a myaddomain.net \
                                -o myserver.myaddomain.net
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -n, --aduser: name of AD user to add objects to
* -a, --addomain: (optional) domain of AD user to add objects to (default is local)
* -o, --objectname: (optional) name of registered object to add to access list (repeat for multiple)
* -vn, --viewname: (optional) name of Cohesity view to add to access list (repeat for multiple)
