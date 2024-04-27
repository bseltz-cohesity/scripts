# Walk Protection Runs using Bash

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script is just an example of how to iterate over protection groups and runs using curl and jq.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/runsExample/runsExample.sh
chmod +x runsExample.sh
# End download commands
```

## Parameters

* -v: cluster vip or endpoint to connect to
* -u: (optional) username to connect to cluster
* -d: (optional) domain of user (defaults to local)
* -p: (optional) password for user
* -k: (optional) api key for authentication
* -n: (optional) number of run to get per API query (default is 10)

## Example

Using username/password authentication (local Cohesity user):

```bash
# example
./runsExample.sh -v mycluster \
                 -u admin \
                 -p Sw0rdFish!
# end example
```

Using API Key authentication:

```bash
# example
./runsExample.sh -v mycluster \
                 -k 1e62583e-4216-45fc-6377-d56e2c5c3776
# end example
```
