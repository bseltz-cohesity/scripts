# Report Protected AWS Objects by Tag (Python)

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script reports on Cohesity-protected AWS objects (EC2 instances and RDS databases) and includes each object's **AWS resource tags** (the tags assigned in AWS itself, e.g. `Environment=Production`, `CostCenter=1234`) in the output. You can optionally filter the report to only objects that carry a specific tag key, or a specific key/value pair.

## Download the script

```bash
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/reports/python/awsProtectedObjectsByTag/awsProtectedObjectsByTag.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x awsProtectedObjectsByTag.py
```

(Note: this script is not yet published in the repo — place the two files from this response in a folder together to run it.)

## Usage examples

```bash
# report all protected AWS objects, with their tags, no filter
./awsProtectedObjectsByTag.py -v mycluster -u myusername -d mydomain.net

# report only objects tagged Environment=Production
./awsProtectedObjectsByTag.py -v mycluster -u myusername -d mydomain.net \
                               -tk Environment -tv Production

# report only objects that carry a CostCenter tag (any value)
./awsProtectedObjectsByTag.py -v mycluster -u myusername -d mydomain.net \
                               -tk CostCenter

# connect through Helios/MCM
./awsProtectedObjectsByTag.py -mcm -u myuser@mydomain.net -c mycluster1 -c mycluster2 \
                               -tk Environment -tv Production
```

## Authentication Parameters

* -v, --vip: (optional, repeat for multiple) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional, repeat for multiple) helios/mcm cluster(s) to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Report Parameters

* -tk, --tagkey: (optional) only include objects that have this AWS tag key
* -tv, --tagvalue: (optional) only include objects where --tagkey equals this exact value (requires --tagkey)
* -o, --objectname: (optional, repeat for multiple) only include specific object name(s)
* -s, --skipdeleted: (optional) skip deleted protection groups
* -x, --units: (optional) MiB or GiB for object size (default GiB)
* -of, --outfolder: (optional) folder to write the CSV to (default current directory)
* -debug, --debug: (optional) print verbose output

## Output

`awsProtectedObjectsByTag-<date>.csv` with one row per protected AWS object:

| Column | Description |
| --- | --- |
| Cluster Name | Cohesity cluster the object was reported from |
| AWS Source | The registered AWS protection source (account/region) the object belongs to |
| Protection Group | Name of the Cohesity protection group protecting the object |
| Policy Name | Protection policy applied to the group |
| Object Name | Name of the EC2 instance or RDS database |
| Object Type | e.g. `EC2Instance`, `RDSInstance` |
| Object ID | Cohesity's internal object ID |
| Front End Size | Logical size of the object, in the selected units |
| Last Backup | Timestamp of the most recent backup run |
| Last Status | Status of the most recent backup run |
| Last Run Type | Full/Incremental/Log |
| Job Paused | Whether the protection group is currently paused |
| AWS Tags | All AWS resource tags on the object, formatted `Key: Value; Key: Value` |
