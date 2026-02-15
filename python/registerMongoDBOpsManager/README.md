# Register MongoDB Ops Manager Protection Sources using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script registers a MongoDB Ops Manager protection sources.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerMongoDBOpsManager/registerMongoDBOpsManager.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x registerMongoDBOpsManager.py
# end download commands
```

## Components

* [registerMongoDBOpsManager.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerMongoDBOpsManager/registerMongoDBOpsManager.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./registerMongoDBOpsManager.py -v mycluster \
                               -u myusername \
                               -d mydomain.net \
                               -n myopsmanager.mydomain.net \
                               -p 8080 \
                               -pubfile mypublickey.pem \
                               -privfile myprivatekey.pem
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -n, --hostname: name of source and primary host to register
* -p, --port: TCP port number
* -certfile, --certificatefile: (optional) path to file containing SSL certificate
* -certificate, --certificate: (optional) certificate (string)
* -pubkey, --publickey: public key (string)
* -privkey, --privatekey: (optional) private key (string, will be prompted if omitted)

## Notes

You must provide the public and private keys using one of the command line parameters (for each key, there is a parameter to use a string or a file).

To enable SSL, provide a certificate using one of the command line parameters (there is a parameter to use a string or a file).
