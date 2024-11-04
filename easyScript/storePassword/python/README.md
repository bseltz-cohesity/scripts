# Store EasyScript Password Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script finds stores a password for use with EasyScript

## Download the Script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/easyScript/storePassword/python/storePassword.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
# end download commands
```

## Storing a Password

Please both files in a folder together and run the script like so:

```bash
python storePassword.py
Enter password for local/helios at helios.cohesity.com: ************************************
```

or

```bash
python storePassword.py -v mycluster -u myuser -d mydomain.net
Enter password for mydomain.net/myuser at mycluster: **********
```

Passwords are obfuscated and stored in a file called YWRtaW4. Once the password is stored, zip this file along with the other script files for upload to EasyScript.

## Arguments

* -v, --vip: (optional) DNS or IP of the Helios endpoint (defaults to helios.cohesity.com)
* -u, --username: (optional) username to store helios API key (defaults to helios)
* -d, --domain: (optional) domain of username to store helios API key (default is local)
* -p, --password: (optional) password to store (you will be prompted for the password by default)
