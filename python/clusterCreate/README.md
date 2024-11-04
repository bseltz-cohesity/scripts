# Create a Cohesity Cluster Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script performs a cluster create, applies a license key and accepts the end-user license agreement, leaving the new cluster fully built and ready for login.

## Download the script

Run these commands to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/clusterCreate/clusterCreate.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/clusterCreate/clusterCreate-test.sh
chmod +x clusterCreate.py
chmod +x clusterCreate-test.sh
# End download commands
```

## Components

* [clusterCreate.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/clusterCreate/clusterCreate.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module
* [clusterCreate-test.sh](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/clusterCreate/clusterCreate-test.sh): example command line

### Note: by running the script, you are accepting the Cohesity End User License Agreement

Place all files in a folder together. then, run the main script like below, or modify the clusterCreate-test.sh with the desired parameters and run that script:

```bash
./clusterCreate.py -s 10.5.64.28 \
                   -u admin \
                   -n 181140263392576 \
                   -n 181140263392540 \
                   -n 181140263384072 \
                   -n 181140263382092 \
                   -v 10.5.64.32 \
                   -v 10.5.64.33 \
                   -v 10.5.64.34 \
                   -v 10.5.64.35 \
                   -c mycluster \
                   -ntp pool.ntp.org \
                   -dns 10.5.64.6 \
                   -dns 10.5.64.7 \
                   -e \
                   -f \
                   -cd mydomain.net \
                   -gw 10.5.64.1 \
                   -m 255.255.254.0 \
                   -igw 10.5.64.1 \
                   -im 255.255.254.0 \
                   -iu admin \
                   -ip admin \
                   -k XXXX-XXXX-XXXX-XXXX
```

## Parameters

* -s, --server: a free node to connect to
* -u, --username: local username to connect to the node
* -n, --nodeid: repeat at least 3 times
* -v, --vip: virtual IPs for cluster, repeat at least 3 times
* -c, --clustername: name of Cohesity cluster
* -m, --netmask: subnet mask for nodes and cluster
* -gw, --gateway: default gateway for nodes and cluster
* -ntp, --ntpserver: ntp server, repeat as desired
* -dns, --dnsserver: dns server, repeat as desired
* -cd, --clusterdomain: default DNS domain for Cohesity cluster
* -z, --dnsdomain: search domain, repeat as desired
* -e, --encrypt: boolean, default is False
* -f, --fips: boolean, enable fips mode, default is False
* -rp, --rotationalpolicy: encryption key rotation days (default is 90)
* -k, --licensekey: Cohesity license key
* -igw, --ipmigateway: default gateway for ipmi connections
* -im, --ipmimask: netmask for ipmi connections
* -iu, --ipmiusername: username for ipmi
* -ip --ipmipassword: password for ipmi
