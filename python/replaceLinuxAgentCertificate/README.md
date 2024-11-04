# Replace Linux Agent Certificate using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script replaces the Cohesity agent certificate on a Linux host.

`Note`: this script requires the paramiko python module. See [Installing - Paramiko documentation](https://www.paramiko.org/installing.html)

## Download the script

Run this commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/replaceLinuxAgentCertificate/replaceLinuxAgentCertificate.py
chmod +x replaceLinuxAgentCertificate.py
```

## Components

* [replaceLinuxAgentCertificate.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/replaceLinuxAgentCertificate/replaceLinuxAgentCertificate.py): the main python script

Run the main script like so:

```bash
#example
./replaceLinuxAgentCertificate.py -s myhost1.mydomain.net -u myusername
#end example
```

## Parameters

* -s, --servername: (optional) one or more hosts to connect to via SSH (repeat for multiple)
* -u, --username: username for SSH connection
* -pwd, --sourcepassword: (optional) will be prompted if omitted
* -f, --certfile: (optional) default is server_cert-**_servername_**
