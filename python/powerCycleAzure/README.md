# Stop and Start Azure Cloud Edition Cohesity Cluster using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script gracefully powers on/off a Cohesity Cloud Edition cluster in Azure.

## Downloading the Files

Go to the folder where you want to download the files, then run the following commands:

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/powerCycleAzure/powerCycleAzure.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/powerCycleAzure/storePassword.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/powerCycleAzure/waitForJob.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/powerCycleAzure/azurece_control.sh
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x azurece_control.sh
```

## Components

* [azurece_control.sh](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/powerCycleAzure/azurece_control.sh): the main bash script
* [powerCycleAzure.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/powerCycleAzure/powerCycleAzure.py): the power on/off process script
* [waitForJob.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/powerCycleAzure/waitForJob.py): waits for inbound replication to complete before poweroff
* [storePassword.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/powerCycleAzure/storePassword.py): script to store passwords
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

### Installing the Prerequisites

```bash
sudo pip install azure-mgmt-compute
```

## Configuring the script

Place all files in a folder together, then open azurece_control.sh in a text editor and configure the following settings at the top of the file:

```bash
ce_ip='10.0.1.6'  # an IP or DNS name of the cloud edition cluster in Azure
ce_user='admin'   # Cohesity user to log onto the cloud edition cluster
ce_domain='local' # Cohesity domain to log onto the cloud edition cluster
node_1='BSeltz-AzureCE-1'  # VM Name of cloud edition node 1
node_2='BSeltz-AzureCE-2'  # VM Name of cloud edition node 2
node_3='BSeltz-AzureCE-3'  # VM Name of cloud edition node 3
key='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'  # Azure application key ID
subscription='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'  # Azure subscription ID
tenant='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'  # Azure AD Directory ID
resgroup='resgroup1'  # Azure resource group name
onprem_ip='192.168.1.198'  # an IP or DNS name of on-prem Cohesity cluster
onprem_user='admin'  # Cohesity user to log onto the on-prem Cohesity cluster
onprem_domain='local'  # Cohesity domain to log onto the on-prem Cohesity cluster
scriptpath='/Users/myusername/scripts/python'  # absolute path to the scripts
```

## Running the Script

First, store the passwords that the script will need later:

```bash
./azurece_control.sh store_passwords
```

```text
Please provide secretkey for Azure
Enter your password:
Re-enter your password:

Please provide password for Cloud Edition user (admin)
Enter your password:
Re-enter your password:

Please provide password for on-prem user (admin)
Enter your password:
Re-enter your password:
```

Then we can stop the cloud edition cluster:

```bash
./azurece_control.sh stop
```

```text
waiting for existing job run to finish...
Connecting to Azure...
Connecting to Cohesity...
Stopping all the cluster services...
Waiting for cluster to stop...
Cluster stopped successfully!
Stopping cloud edition instances...
```

and start the cluster:

```bash
./azurece_control.sh start
```

```text
Connecting to Azure...
Starting cloud edition instances...
Connecting to Cohesity...
Starting all the cluster services...
Waiting for cluster to start...
Cluster started successfully!
```

## CRON entries

Example: start the cluster at 5PM, and stop it at 5AM

```bash
0 17 * * * /home/myusername/scripts/azurece_control.sh start
0 5 * * * /home/myusername/scripts/azurece_control.sh stop
```
