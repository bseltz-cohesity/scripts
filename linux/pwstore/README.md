# Store and Retrieve an Encrypted Password for Linux

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a compiled binary that stores and retrieves a password from an encrypted file. This is useful when you need to pass a password to a command like iris_cli

## Download The Binary

<https://github.com/cohesity/community-automation-samples/raw/main/linux/pwstore/pwstore>

Run the tool like so:

```bash
# example

# grant execute permissions
chmod +x pwstore

# store a password
./pwstore -v mycluster -u myusername -d mydomain.net
  Enter new password: ********
Confirm new password: ********

# retrieve a password
./pwstore -v mycluster -u myusername -d mydomain.net -g
Sw0rdFi$h

# retrieve a password into a bash variable
mypassword=$(./pwstore -v mycluster -u myusername -d mydomain.net -g)
echo $mypassword
Sw0rdFi$h

# retrieve a password embedded in a command
./iris_cli -server mycluster -username myusername -domain mydomain.net -password $(./pwstore -v mycluster -u myusername -d mydomain.net -g) cluster ls-gflags

# end example
```

## Parameters

* -v, --vip: name of endpoint for which the password is associated
* -u, --username: username for which the password is associated
* -d, --domain: (optional) domain of username, defaults to local
* -pwd, --password: (optional) will be prompted if omitted and not stored
* -g, --get: (optional) retrieve the password (will store password if omitted)
