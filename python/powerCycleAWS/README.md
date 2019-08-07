# Stop and Start AWS Cloud Edition Cohesity Cluster using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script gracefully powers on/off a Cohesity Cloud Edition cluster in AWS.

## Downloading the Files

Go to the folder where you want to download the files, then run the following commands:

```bash
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/powerCycleAWS/powerCycleAWS.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/powerCycleAWS/pyhesity.py
chmod +x powerCycleAWS.py
```

## Components

* powerCycleAWS.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

## Dependencies

See below...

## Running the Script

Place both files in a folder together and run the main script like so:

```bash
./powerCycleAWS.py -s 172.31.28.144 -u admin -o poweroff -n i-00b359f39aa83551d -n i-0aa0725c31c208d63 -n i-0fcc7118fb230b47e -k XXXXXXXXXXXXXXXXXXXX -r us-east-2
```

```text
Connecting to ec2...
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
* -n, --node: the AWS instance ID of a node. Include multiple nodes like: -n i-xxx1 -n i-xxx2, -n i-xxx3
* -k, --aws_access_key_id: aws access key ID (you will be prompted for your secret key)
* -r, --region: aws region where the cloud edition nodes reside

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

### Installing the Prerequisites

```bash
sudo yum install python-requests python-boto3
```

or

```bash
sudo easy_install requests
sudo easy_install boto3
```
