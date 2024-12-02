# Copy Roles using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script creates a new S3 View on Cohesity

## Download the script

Run these commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/copyRoles/copyRoles.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x copyRoles.py
```

## Components

* [copyRoles.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/copyRoles/copyRoles.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To copy all custom roles from one cluster to another:

```bash
#example
./copyRoles.py -sc cluster1 \
               -su username1 \
               -sd mydomain.net \
               -tc cluster2
#end example
```

To copy specific roles:

```bash
#example
./copyRoles.py -sc cluster1 \
               -su username1 \
               -sd mydomain.net \
               -tc cluster2 \
               -n role1 \
               -n role2
#end example
```

## Authentication Parameters

* -sc, --sourcecluster: Source Cohesity cluster to connect to
* -su, --sourceusername: Source cluster Cohesity username
* -sd, --domain: (optional) Source cluster Active Directory domain (defaults to 'local')
* -spwd, --sourcepassword: (optional) will be prompted or use stored password if omitted
* -tc, --targetcluster: Target Cohesity cluster to connect to
* -tu, --targetusername: (optional) Target cluster Cohesity username (defaults to sourceusername)
* -td, --targetdomain: (optional) Target cluster Active Directory domain (defaults to sourcedomain)
* -tpwd, --targetpassword: (optional) will be prompted or use stored password if omitted
* -i, --useApiKey: (optional) use API key authentication

## Other Parameters

* -n, --rolename: (optional) name of role to copy (repeat for multiple)
* -l, --rolelist: (optional) text file of role names to copy (one per line)
* -o, --overwrite: (optional) replace existing roles on target cluster
