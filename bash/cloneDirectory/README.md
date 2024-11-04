# Clone Directory using Bash

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This bash script clones a directory from one view to another.

## Download the script

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/bash/cloneDirectory/cloneDirectory.sh
chmod +x cloneDirectory.sh
# End download commands
```

## Parameters

* -v: cluster vip or endpoint to connect to
* -k: api key for authentication
* -s: source path (e.g. VIEW1/my/path)
* -t: target path (e.g. VIEW2/your)
* -d: target dir (e.g. new)

## Example

To clone the /bash folder from the myscripts view to to /curl/bash2 folder in the myscripts view:

```bash
# example
./cloneDirectory.sh -v ve4 \
                    -s 'myscripts/bash' \
                    -t 'myscripts/curl' \
                    -d 'bash2' \
                    -k 1e62583e-4216-45fc-6377-d56e2c5c3776
# end example
```
