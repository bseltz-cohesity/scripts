# Deploy Cohesity Virtual Edition Cluster Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Support for Python Versions

This script may not work on Python 3 on Windows as there seem to be some issues with pyvmomi. This script was tested on CentOS 7.6 running Python 2.7.5.

## Note: Please use the download commands below to download the script

This Python script deploys a multi-node Cohesity Clustered Virtual Edition (CVE) cluster on VMware vSphere. After deploying the OVAs, the script performs the cluster setup, and optionally applies a license key and accepts the end-user license agreement, leaving the new cluster fully built and ready for login.

## Download the script

Run these commands to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/deployCVE/deployCVEcluster.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/deployCVE/test-deployCVE.sh
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/excludeVMs/pyVmomi.tar.gz
tar -xvf pyVmomi.tar.gz
chmod +x deployCVEcluster.py
chmod +x test-deployCVE.sh
# End download commands
```

## Components

* [deployCVEcluster.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/deployCVE/deployCVEcluster.py): the main python script
* cohesity-api.ps1: the Cohesity REST API helper module
* [test-deployCVE.sh](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/deployCVE/test-deployCVE.sh): example command line
* pyVmomi: Python SDK for the VMware vSphere API (see attributions below)

Place all files in a folder together. then, run the main script like so:

```bash
./deployCVEcluster.py  -vc 10.2.143.29 \
                -vu administrator@vsphere.local \
                -vp myvcpassword \
                -ds datastore1 \
                -ds datastore2 \
                -ds datastore3 \
                -f ./cohesity-6.1.1d_release-20190507_1eef123c-8tb.ova \
                -vh 10.2.137.37 \
                -vh 10.2.137.37 \
                -vh 10.2.137.37 \
                --vmname BSeltz-CVE1 \
                --vmname BSeltz-CVE2 \
                --vmname BSeltz-CVE3 \
                -ip 10.2.143.48 \
                -ip 10.2.143.49 \
                -ip 10.2.143.50 \
                -v 10.2.143.51 \
                -v 10.2.143.52 \
                -v 10.2.143.53 \
                -m 255.255.248.0 \
                -g 10.2.136.1 \
                -c BSeltz-CVE \
                -ntp pool.ntp.org \
                -dns 10.2.143.28 \
                -e \
                --fips \
                -cd sa.corp.cohesity.com \
                -k ABDC-EFGH-IJKL-MNOP \
                --accept_eula
```

```text
Deploying OVA...
adding disks...
52GB disk added to BSeltz-CVE1
250GB disk added to BSeltz-CVE1
powering on VM...
OVA Deployment Complete!
Deploying OVA...
adding disks...
52GB disk added to BSeltz-CVE2
250GB disk added to BSeltz-CVE2
powering on VM...
OVA Deployment Complete!
Deploying OVA...
adding disks...
52GB disk added to BSeltz-CVE3
250GB disk added to BSeltz-CVE3
powering on VM...
OVA Deployment Complete!
waiting for nodes to come online...
2 of 3 free nodes found
3 of 3 free nodes found
Creating Cluster BSeltz-CVE...
Waiting for cluster creation...
New Cluster ID is: 4952153157885044
Waiting for services to start...
Cluster Services are Started
Accepting EULA and Applying License Key...
Cluster Creation Successful!
```

## Note: by using the --accept_eula parameter below, you are accepting the Cohesity End User License Agreement

## Parameters

* -vc, --vcenter: vcenter to connect to
* -vu, --viuser: vcenter username
* -vp, --vipassword: vcenter password (will prompt if omitted)
* -dc, --datacenter_name: optional. vSphere datacenter to deploy into
* -ds, --datastore_name: repeat at least 3 times
* -vh, --host_name: vsphere host or cluster, repeat at least 3 times
* -f, --ova_path: path to local OVA file
* -n, --vmname: repeat at least 3 times
* -md, --metasize: size of metadata disk, in GB
* -dd, --datasize: size of data disk, in GB
* -n1, --network1: primary VM network
* -n2, --network2: secondary VM network
* -ip, --ip: node IP, repeat at least 3 times
* -m, --netmask: subnet mask for nodes and cluster
* -g, --gateway: default gateway for nodes and cluster
* -v, --vip: virtual IPs for cluster, repeat at least 3 times
* -c, --clustername: name of Cohesity cluster
* -ntp, --ntpserver: ntp server, repeat as desired
* -dns, --dnsserver: dns server, repeat as desired
* -e, --encrypt: boolean, default is False
* -cd, --clusterdomain: default DNS domain for Cohesity cluster
* -z, --dnsdomain: search domain, repeat as desired
* -rp, --rotationalpolicy: encryption key rotation days (default is 90)
* --fips: boolean, enable fips mode, default is False
* -k, --licensekey: optional. Required if --accept_eula is present
* --accept_eula: optional. If present, eula will be accepted

### Attributions

Thanks to VMware for the pyVmomi Python SDK for the VMware vSphere API. Located here: <https://github.com/vmware/pyvmomi>

I'm using pyVmomi here to deploy the Cohesity Clustered Virtual Edition OVA.

Normally I would advise users to do a proper install of pyVmomi, which would allow this script to work fine, but there's a strong likelihood of this script being deployed onto a Cohesity cluster, and I wouldn't advise installing pyVmomi on a Cohesity cluster (it might get wiped out during a Cohesity upgrade). So, I've decided to deliver pyVmomi as part of this script in portable form.
