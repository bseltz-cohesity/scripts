# Stop and Start Azure Cloud Edition Cohesity Cluster using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script gracefully powers on/off a Cohesity Cloud Edition cluster in Azure.

## Downloading the Files

Go to the folder where you want to download the files, then run the following commands:

```bash
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/powerCycleAzure/powerCycleAzure.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/powerCycleAzure/pyhesity.py
chmod +x powerCycleAzure.py
```

## Components

* powerCycleAzure.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

## Dependencies

See below...

## Running the Script

Place both files in a folder together and run the main script like so:

```bash
./powerCycleAzure.py -s 10.0.1.6 \
                     -u admin \
                     -o poweroff \
                     -n BSeltz-AzureCE-1 \
                     -n BSeltz-AzureCE-2 \
                     -n BSeltz-AzureCE-3 \
                     -k xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
                     -t xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
                     -b xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
                     -r resgroup1
```

```text
Connecting to azure...
Connecting to Cohesity...
Stopping all the cluster services...
Waiting for cluster to stop...
Cluster stopped successfully!
Stopping cloud edition instances...
```

## Parameters

* -s, --server: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -o, --operation: poweron or poweroff
* -n, --node: the name of the Azure VM instance of a node. Include multiple nodes like: -n xxx1 -n xxx2, -n xxx3
* -k, --accesskey: Azure access key ID (you will be prompted for your secret key)
* -t, --tenant: Azure AD directory ID
* -b, --subscription: Azure subscription ID
* -r, --resourcegroup: Azure resource group where VMs reside

### Installing the Prerequisites

```bash
sudo pip install azure-mgmt-compute
```
