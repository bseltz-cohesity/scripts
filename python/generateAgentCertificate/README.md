# Generate a New Agent Certificate using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script generates a new agent certificate.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/generateAgentCertificate/generateAgentCertificate.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x generateAgentCertificate.py
# end download commands
```

## Components

* generateAgentCertificate.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./generateAgentCertificate.py -v mycluster \
                              -u myuser \
                              -d mydomain.net \
                              -s myserver.mydomain.net
```

To include multiple subject alternate names, repeat the -s parameter:

```bash
./generateAgentCertificate.py -v mycluster \
                              -u myuser \
                              -d mydomain.net \
                              -s myserver.mydomain.net \
                              -s myserver \
                              -s 192.168.3.100
```

## Authentication Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -m, --mfacode: (optional) MFA code for authentication
* -e --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -s, --servername: name of server as is/will be registered in Cohesity (repeat to include multiple subject alternate names)
* -country, --country: (optional) country code (default is US)
* -state, --state: (optional) state code (default is CA)
* -city, --city: (optional) city code (default is SN)
* -org, --organization: (optional) organization (default is Cohesity)
* -ou, --organizationUnit: (optional) organization unit (default is IT)
* -x, --expirydays: (optional) number of days until expiration (default is 365)
