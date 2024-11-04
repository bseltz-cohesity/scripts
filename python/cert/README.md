# Certificate Improvements using Python

The script helps initialise certificate handling for clusters using multi-cluster registration or protecting HyperV data

Contributor: Priyadharsini

## Components

* [cert.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/cert/cert.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py): the Cohesity REST API helper module: the Cohesity python helper module
* python requests module (see "Installing the Prerequisites" section below)

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/cert/cert.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py
chmod +x cert.py
# end download commands
```

Place both files in a folder together. The basic form of the command is:

```bash
# example
./cert.py --cluster cluster.json
```

But we must first create the cluster.json file:

Multi-cluster Environment - Designate any cluster in your environment as primary cluster from which keys would be copied to all the other clusters. This is to obtain the set of keys to keep a uniform trust chain across all clusters

cluster.json file sample - Multi-Cluster:

```bash
{
    "primary": 
        {
            "ip":"10.2.20.17", 
            "username":"admin",
            "mfaCode":"1234"
        },
    "targets": 
    [
        {
            "ip":"10.2.20.1", 
            "username":"admin", 
            "password":"1234"
        }
    ]
}
```

For Single Cluster Environment, there will be only primary cluster described on cluster.json

cluster.json file sample - Single Cluster:

```bash
{
    "primary": 
        {
            "ip":"10.2.20.17", 
            "username":"admin",
            "mfaCode":"1234"
        }
}
```

Disaster-Recovery without MT:

```bash
./cert.py --cluster cluster.json --dr
```

When --dr flag is passed, it signifies that the target clusters will be initialized with the source cluster keys and vice-versa. Its important to ensure that both the source and target clusters are provided as lists.

cluster.json file sample:

```bash
{
    "sources": 
        [
            {
            "ip":"10.2.20.17", 
            "username":"admin",
            "mfaCode":"1234"
            }
        ],
    "targets": 
    [
        {
            "ip":"10.2.20.1", 
            "username":"admin", 
            "password":"1234"
        }
    ]
}
```

If password is not provided with file, you will be prompted on terminal,
If MFA is enabled, please provide MFACode for Totp.
NOTE: scripted MFA via email is disabled

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

## The Python Main Module - cert.py

This module helps with bootstrapping each target cluster with primary cluster's Cohesity CA Keys

## Installing the Prerequisites

```bash
# using yum
sudo yum install python3-requests

# or using dnf
sudo dnf install python3-requests

# or using apt
sudo apt-get install python3-requests

# or using easy_install
sudo easy_install requests

# or using pip
pip3 install requests
```

Or, using a Python Virtual Environment

```bash
# Install virtualenv
sudo pip3 install virtualenv

# Create myenv
python3 -m venv myenv

# Enter myenv
source myenv/bin/activate

# Install requests in myenv
pip3 install requests

# download the cert.py script
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/cert/cert.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py
chmod +x cert.py

# run the cert.py script
./cert.py --cluster cluster.json

# Exit virtualenv
deactivate
```
