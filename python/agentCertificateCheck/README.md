# Report Agent Certificates using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script will report certificate expirations for registered agents. The script will output two files: `agentCertificateCheck-clusterName-DateTime.csv` will contain a detailed report, and `impactedAgents-clusterName-dateTime.txt` will contain the names of agents that require urgent upgrade. The text file can be used as input to the upgradeAgents.py script: <https://github.com/cohesity/community-automation-samples/tree/main/python/upgradeAgents>

Note: this script will only run on Linux where the openssl command is available. You can run it directly on the Cohesity cluster if shell access is available, or on a linux host. The script requires direct network access to the hosts via port 50051/tcp, so inter-site firewall rules would be problematic.

## Components

* [agentCertificateCheck.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/agentCertificateCheck/agentCertificateCheck.py): the main python script - md5 checksum: 548c078028382035f7a41c9f4308d8df
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module - md5 checksum: 2147a0db6ec080eb3a489b4a0325e0ce

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/agentCertificateCheck/agentCertificateCheck.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x agentCertificateCheck.py
# end download commands
```

## Prerequisites To Run The Script

```bash
chmod +x agentCertificateCheck.py
```

If the 'chmod' prerequsite cannot be run for any reason, please run the script with the precurser 'python3' (or 'python' depending on the version python currently installed on the system) like:

```bash
python3 agentCertificateCheck.py -v mycluster -u myuser -d local
```

To verify the version of python currently installed on the system:

```bash
python --version
```

## Examples

Running the script against one cluster (with direct authentication):

```bash
./agentCertificateCheck.py -v mycluster -u myuser -d local  # -d myAdDomain.net (for active directory)
```

Running the script against all Helios clusters (note: you will need to create an API key in helios and use that as the password when prompted):

```bash
./agentCertificateCheck.py -u myuser@mydomain.net
```

Running the script against selected Helios clusters (note: you will need to create an API key in helios and use that as the password when prompted):

```bash
./agentCertificateCheck.py -u myuser@mydomain.net -c cluster1 -c cluster2
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to (will loop through all clusters if connected to helios)
* -m, --mfacode: (optional) MFA code for authentication

## Other Parameters

* -w, --excludewindows: (optional) skip windows sources
* -x, --expirywarningmonths: (optional) report impacted if agent will expire in within X months( default is 6)

## Running the Script on a Linux Jump Host

Running the script from a jump host can be problematic because the script requires a python module called `requests` to be installed. If not already installed, customers may face confusion around error messages, python versions, and module installation steps, requiring someone with python expertise to assist.

Customer `firewall rules` may block access to the Cohesity cluster. This causes the script to hang for some time until the connection times out.

`Firewall rules` may also block the jump host from reaching the cluster's agents. This causes agents to be reported as `unreachable` with a certificate expiration date of `unknown`, thus defeating the purpose of the script.

## Running the Script on the Cluster

This has the best chance of success, even if it means contacting support to enable host shell access (6.7x and later). All dependencies are already installed and the firewall will allow the script to reach the agents. Use `-v localhost` as some clusters can't resolve their own DNS name. You can use an IP address (node IP or VIP) but using localhost saves you the trouble of finding an IP.

Use an account with `admin rights`. This allows the discovery of gflags that customize agent port numbers. Without these rights, gflag discovery is skipped leading to unreachable/unknown agents if they are using custom port numbers (this is uncommon).

If using an account that has `MFA` enabled, add `-m xxxxxx` to the command line (replace xxxxxx with the current OTP code from your authenticator app).

## Using Helios

Connecting through helios is great because the script can loop through all of the customer's clusters in one shot, but again, if customer `firewall rules` are tightly controlled, the script running on clusterA may not be able to reach clusterB's agents, causing agents again to be reported as unreachable/unknown. In this case, you must run the script from each cluster, one at a time.

## Authenticating to Helios

See official doc here: <https://docs.cohesity.com/WebHelios/Content/Helios/Access_Management.htm#ManageAPIKeys>

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon (settings) -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When connecting to helios, if you are prompted for a password, enter the API key as the password.

## What Does Unknown Mean

There are several failure modes that can result in a lack of response or lack of details returned for an agent, resulting in 'unknown' in the script output. For example:

* **Agent never successfully registered**: this can happen if the agent was already registered with another cluster when registration was attempted. In this case, the agent will appear unreachable and most of the details will remain unknown.

* **Agent was successfully registered but is now offline**: in this case we will have some of the details from the last time the cluster conversed with the agent, but since it's now offline, it will appear unreachable and the certificate date will remain unknown.

* **Agent is not reachable over the network**: this may be caused by running the script from a jump host that does not have direct access to the agent hosts, likely due to firewall rules or air gapped networks that the jump host can't reach. Running the script directly on the cluster may alleviate some of these issues. It may also be that Hybrid Extender (HyX) is in use and therefore no direct network access is possible. Again, we will successfully retrieve some of the agent details but the agent will appear unreachable and the certificate date will remain unknown.

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
