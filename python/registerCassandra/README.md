# Register Cassandra Protection Sources using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script registers Cassandra protection sources.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerCassandra/registerCassandra.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x registerCassandra.py
# end download commands
```

## Components

* [registerCassandra.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerCassandra/registerCassandra.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./registerCassandra.py -v mycluster \
                       -u myusername \
                       -d mydomain.net \
                       -n cassandra1.mydomain.net,192.168.1.101 \
                       -cd /etc/dse/cassandra \
                       -dd /etc/dse \
                       -da \
                       -su root \
                       -ju cassandra
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

* -n, --servername: name of server:port to register (repeat for multiple)
* -l, --serverlist: text file containing list of servers to register (one per line)
* -cd, --configdir: cassandra configuration directory
* -dc, --datacenter: (optional) datacenter name (repeat for multiple)
* -cl, --commitlog: (optional) commit logs backup directory
* -dd, --dseconfigdir: (optional) DSE configuration directory
* -dt, --dsetieredstorage: (optional) DSE tiered storage is present
* -da, --dseauthenticator: (optional) DSE authenticator is present
* -dn, --dsesolrnode: (optional) DSE Solr node IP address (repeat for mutiple)
* -dp, --dsesolrport: (optional) DSE Solr port
* -su, --sshusername: SSH username
* -sp, --sshpassword: (optional) SSH password (will be prompted if omitted)
* -pp, --promptforpassphrase: (optional) prompt for SSH private key passphrase (otherwise use sshpassword)
* -sk, --sshprivatekeyfile: (optional) path to SSH private key file
* -ju, --jmxusername: (optional) JMX username
* -jp, --jmxpassword: (optional) JMX password (will be prompted if omitted)
* -cu, --cassandrausername: (optional) cassandra username
* -cp, --cassandrapassword: (optional) cassandra password (will be prompted if omitted)
* -kp, --kerberosprincipal: (optional) kerberos principal
