# Add a Node to a Cohesity Cluster using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script adds a free node to a cluster.

## Components

* [nodeAdd.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/nodeAdd/nodeAdd.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
bash:~/python$ ./nodeAdd.py -v mycluster -u admin -v 10.1.15.223
Connected!
adding VIP 10.1.15.223
Adding node 215507192131180 to cluster
Expanding cluster having id 775397535002324 and name mycluster in progress...
```

The full syntax of the command is:
```bash
bash:~/python$ ./nodeAdd.py -s mycluster -u admin [ -d mydomain ] \
    [ -i nodeIP ] [ -p ipmiIP ] [ -n nodeId ] [ -v newVIP]
```

Syntax notes:

* domain defaults to local if not specified
* nodeIP must be already configured on the node if not specified
* ipmiIP must be already configured on the node if not specified
* nodeId will default to a free node in the same chassis if possible, otherwise will use the first free node found, if not specified
* newVIP is required if a spare VIP doesn't already exist on the cluster

Note: The script does not add the newVIP to DNS. 

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
