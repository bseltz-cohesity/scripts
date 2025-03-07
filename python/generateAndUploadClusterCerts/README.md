# Generate certificate from one cluster and Upload to another cluster using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script generates a new certificate from each primary cluster specificied (using the primary cluster's CA) and uploads the generated certificates to the target vault cluster, so that agents can registered with the target cluster.

Contributor: Guna Chidambaram

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/generateAndUploadClusterCerts/generateAndUploadClusterCerts.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x generateAndUploadClusterCerts.py
# end download commands
```

## Components

* [generateAndUploadClusterCerts.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/generateAndUploadClusterCerts/generateAndUploadClusterCerts.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To generate one cert from each primary cluster and upload the new certificates to the target vault cluster:

```bash
# example
./generateAndUploadClusterCerts.py --config cluster-cert.json
# end example
```

To generate one cert from each primary cluster and write it to a file (`generated_certs.json`) in the same directory:

```bash
# example
./generateAndUploadClusterCerts.py --config cluster-cert.json --generate
# end example
```

To upload the certificates in the (`generated_certs.json`) file in the same directory to the target vault cluster:

```bash
# example
./generateAndUploadClusterCerts.py --config cluster-cert.json --upload
# end example
```

But we must first create the cluster-cert.json file:

Designate primary clusters in your Cohesity environments from which certificates would be generated and uploaded to the target vault cluster.

cluster-cert.json file sample - Multiple primary clusters and a single target vault cluster details:

```bash
{
    "primary_clusters":
    [
        {
            "ip": "10.2.20.17", 
            "username": "admin",
            "mfaCode": "1234",
        }
    ],
    "target_vault_cluster": 
    {
        "ip": "10.2.20.1", 
        "username": "admin", 
        "password": "1234"
    }
}
```

If password is not provided with file, you will be prompted on terminal,
If MFA is enabled, please provide MFACode for Totp.
NOTE: scripted MFA via email is disabled

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

## The Python Main Module - generateAndUploadClusterCerts.py

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
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/generateAndUploadClusterCerts/generateAndUploadClusterCerts.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py
chmod +x generateAndUploadClusterCerts.py

# run the cert.py script
./generateAndUploadClusterCerts.py --config cluster-cert.json [--generate] [--upload]

# Exit virtualenv
deactivate
```
