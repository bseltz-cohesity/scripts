# Upload an SSL Certificate using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script uploads and installs an SSL certificate and private key onto a Cohesity cluster.

## Components

* [uploadSSLCertificate.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/uploadSSLCertificate/uploadSSLCertificate.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/uploadSSLCertificate/uploadSSLCertificate.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x uploadSSLCertificate.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./uploadSSLCertificate.py -v mycluster \
                          -u myusername \
                          -d mydomain.net \
                          -c ./mycluster_cert.pem \
                          -k ./mycluster_key.pem
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -c, --certfile: path to certificate file (in PEM format)
* -k, --keyfile: path to private key file (in PEM format)

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
