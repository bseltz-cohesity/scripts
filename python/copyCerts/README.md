# Copy CA Certificates from One Cluster to Another Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script copies the CA certificate chain and private key from one cluster to another, so that multi-cluster agent registration is possible.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/copyCerts/copyCerts.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x copyCerts.py
# end download commands
```

## Components

* [copyCerts.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/copyCerts/copyCerts.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To copy certs from one cluster to another:

```bash
# example
./copyCerts.py -sc mycluster1 \
               -su myuser1 \
               -tc mycluster2 \
               -tu myuser2
# end example
```

To restore a cluster's original certs:

```bash
# example
./copyCerts.py -tc mycluster2 \
               -tu myuser2 \
               -r
# end example
```

## Parameters

* -sc, --sourcecluster: (optional) name or IP of source Cohesity cluster
* -su, --sourceuser: (optional) name of user to connect to source cluster
* -sd, --sourcedomain: (optional) your AD domain (defaults to local)
* -tc, --targetcluster: name or IP of source Cohesity cluster
* -tu, --targetuser: name of user to connect to source cluster
* -td, --targetdomain: (optional) your AD domain (defaults to local)
* -k, --useapikeys: (optional) use API keys for authentication
* -m, --promptformfacode: (optional) prompt for MFA codes
* -r, --restore: (optional) restore target cluster certs from backup file
