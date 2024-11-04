# Remove a Node from a Cohesity Cluster using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script removes a node from a cluster. Before proceeding, the script will check that:

* new cluster size will satisfy the required minimum number of nodes
* percent of space consumed will remain below the maxFull threashold
* cluster is healthy (no currently failed nodes or disks)

## Components

* [nodeRemove.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/nodeRemove/nodeRemove.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
bash:~/python$ ./nodeRemove.py -v 10.1.1.211 -u admin
Connected!
Removing node 215507192131180
```

The full syntax of the command is:
```bash
bash:~/python$ ./nodeRemove.py -v mycluster -u admin [ -d mydomain ] \
    [ -n nodeId ] [ -m maxFull ]
```

Syntax notes:

* domain defaults to local if not specified
* nodeId will default to a last node added to the cluster if not specified
* maxFull defaults to 70 (70%) if not specified

Note: The script will not remove a VIP from the cluster, to avoid any connectivity issues. The extra VIP can be removed after removing its DNS entry and letting any cached DNS referrals expire.

## The Python Helper Module - pyhesity.py
The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

### Installing the Prerequisites
```bash
sudo yum install python-requests
```
or

```bash
sudo easy_install requests
```
