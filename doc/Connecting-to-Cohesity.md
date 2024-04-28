# Connecting Scripts to Cohesity

## Quick Note About Examples Below

The examples given below are shown in multi-line format, for readability, using `line continuation characters` at the end of each line (except the last line).

* The line continuation character for PowerShell is the back tick ` character.
* The line continuation character for bash is the back slash \ character.

`Note`: the line continuation character must be proceeded by a single space! Also, the line continuation character must be the last character on that line!

Any blank line or missing line continuation character will cause the command options to end prematurely, leading to incorrect behavior. For example:

PowerShell Example:

```powershell
# WRONG! missing line continuation character
.\storagePerObjectReport.ps1 -vip mycluster.mydomain.net `
                             -username myuser  # <-- WRONG! missing line continuation character!!!
                             -domain mydomain.net `
                             -mfaCode 417255
```

In the example above, the last two lines are `not` part of the command, because of the missing back tick.

Python Example:

```bash
# WRONG! blank line
./storagePerObjectReport.py -v mycluster.mydomain.net \
                                              # <-- WRONG! blank line!!!
                            -u myuser \

                            -domain mydomain.net \

                            -mfaCode 417255
```

In the example above, the command ends after the first line, because of the blank line.

## API Endpoints

The scripts in this repository connect to Cohesity clusters using the Cohesity REST API. The scripts can connect:

* Directly to the cluster (VIP or node IP), port 443/tcp
* Directly to the cluster, over support channel, localhost:*gui-port*
* Indirectly through <https://helios.cohesity.com>, port 443/tcp
* Indirectly through MCM, port 443/tcp

The scripts in this repository refer to these endpoints as -vip (powershell), -v or --vip (python)

If access to the endpoint via port 443/tcp is blocked by a firewall, then connection will fail.

## Authentication Types

Two types of authentication are available depending on the endpoint:

* Username/Password authentication - only supported for direct cluster connection (and support channel)
* API Key authentication - supported for all endpoints

In all cases, a user must be registered (granted a role) on the cluster or in Helios/MCM. The user can be a local or Active Directory user. `SSO users are currently not supported for use with scripts`.

## Direct Cluster Connection

When connecting directly to a cluster, you must have a user that is registered under Access Management (granted a role) in the cluster. This can be a local user or an Active Directory user. `SSO users are not currently supported`.

### Username/Password Authentication

Simply provide the vip, username and the fully-qualified domain name, and enter the password when prompted:

`Note`: command line options may vary, please review the README for any script you are trying to use

`Note`: short domain names (e.g. MYDOMAIN) will not work. You must use the fully-qualified domain name (e.g. MYDOMAIN.NET)

PowerShell Examples:

```powershell
# example using a local user account
.\storagePerObjectReport.ps1 -vip mycluster.mydomain.net `
                             -username myuser

# example using an Active Directory user account
.\storagePerObjectReport.ps1 -vip mycluster.mydomain.net `
                             -username myuser `
                             -domain mydomain.net
```

You can also provide the password on the command line (not recommended):

```powershell
# example using a local user account
.\storagePerObjectReport.ps1 -vip mycluster.mydomain.net `
                             -username myuser `
                             -password Sw0rdFish

# example using an Active Directory user account
.\storagePerObjectReport.ps1 -vip mycluster.mydomain.net `
                             -username myuser `
                             -domain mydomain.net `
                             -password Sw0rdFish
```

Python Examples:

```bash
# example using a local user account
./storagePerObjectReport.py -v mycluster.mydomain.net \
                            -u myuser

# example using an Active Directory user account
./storagePerObjectReport.py -v mycluster.mydomain.net \
                            -u myuser \
                            -d mydomain.net
```

You can also provide the password on the command line (not recommended):

```bash
# example using a local user account
./storagePerObjectReport.py -v mycluster.mydomain.net `
                            -u myuser `
                            -pwd Sw0rdFish

# example using an Active Directory user account
./storagePerObjectReport.py -v mycluster.mydomain.net \
                            -u myuser \
                            -domain mydomain.net \
                            -pwd Sw0rdFish
```

Note that the password will be stored in protected storage for future use so that scripts can be run unattended.

### Multi-Factor Authentication

When using Username/Password authentication and MFA is enabled for the user, you must provide the OTP code. This is fine when you want to run a script interactively, but is a show stopper if you want to schedule scripts to run unattended. In this case, you should use API key authentication (see below).

`Note`: Many scripts have the MFA command line option, but if you find an older script without it, please request it be added if needed.

PowerShell Example:

```powershell
# example using an Active Directory user account
.\storagePerObjectReport.ps1 -vip mycluster.mydomain.net `
                             -username myuser `
                             -domain mydomain.net `
                             -mfaCode 417255
```

Python Example:

```bash
# example using an Active Directory user account
./storagePerObjectReport.py -v mycluster.mydomain.net \
                            -u myuser \
                            -domain mydomain.net \
                            -mfaCode 417255
```

### API Key Authentication

You can create an API key for a user and use it for authentication. The API key is a static credential that will not change when the user's password changes. API key authentication also bypasses MFA, so is the best choice if you want to run scripts unattended.

To create an API key for a user, please see instructions here: <https://github.com/cohesity/community-automation-samples/blob/main/doc/API-Key-Authentication.md>

Once you have created an API key for the user, you can tell the script to use API key authentication, then use the API key as the password:

PowerShell Example:

Enter the API key as the password when prompted:

```powershell
# example using API key authentication
.\backupNow.ps1 -vip mycluster.mydomain.net `
                -username myuser `
                -jobName myjob `
                -useApiKey
# end example
```

or use the API key as the password on the command line:

```powershell
# example using API key authentication
.\backupNow.ps1 -vip mycluster.mydomain.net `
                -username myuser `
                -jobName myjob `
                -useApiKey `
                -password xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# end example
```

Python Example:

Enter the API key as the password when prompted:

```bash
# example using API key authentication
./backupNow.py -v mycluster.mydomain.net \
               -u myuser \
               -j myjob \
               --useApiKey
# end example
```

or use the API key as the password on the command line:

```bash
# example using API key authentication
./backupNow.py -v mycluster.mydomain.net \
               -u myuser \
               -j myjob \
               --useApiKey \
               -p xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# end example
```

## Connecting Through Helios or MCM

`Note`: Helios and MCM support only API Key authentication.

`Note`: SSO users are not currently supported

To create an API key for a user:

* log onto Helios `as that user`
* click the gear icon (settings) -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Note: Most scripts support Helios/MCM connection. IF you find an older script that doesn't support it, please request it ba added.

## Connecting Through Helios

`Note`: SSO users are not currently supported

When connecting to Helios, we do not need to specify an endpoint (vip), because it is the default. We do have to specify which cluster to select after connecting to Helios.

`Note`: specify the cluster name as short name as listed in Helios (not FQDN)

PowerShell Example:

```powershell
# example using API key authentication
.\backupNow.ps1 -clusterName mycluster `
                -username myuser `
                -jobName myjob
# end example
```

or specify the API key on the commandline

```powershell
# example using API key authentication
.\backupNow.ps1 -clusterName mycluster `
                -username myuser `
                -jobName myjob `
                -password xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# end example
```

Python Examples:

```bash
# example using API key authentication
./backupNow.py -c mycluster \
               -u myuser \
               -j myjob
# end example
```

or specify the API key on the command line:

```bash
# example using API key authentication
./backupNow.py -c mycluster \
               -u myuser \
               -j myjob \
               -p xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# end example
```

## Connecting Through MCM

`Note`: SSO users are not currently supported

When connecting to MCM, we need to specify both the endpoint (vip) and the cluster to select after connecting to MCM. Also, we specify `-mcm` which tells the script that the endpoint is MCM rather than a cluster.

`Note`: specify the cluster name as short name as listed in MCM (not FQDN)

PowerShell Example:

```powershell
# example using API key authentication
.\backupNow.ps1 -vip mcm.mydomain.net `
                -clusterName mycluster `
                -username myuser `
                -jobName myjob `
                -mcm
# end example
```

or specify the API key on the commandline

```powershell
# example using API key authentication
.\backupNow.ps1 -vip mcm.mydomain.net `
                -clusterName mycluster `
                -username myuser `
                -jobName myjob `
                -password xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx `
                -mcm
# end example
```

Python Examples:

```bash
# example using API key authentication
./backupNow.py -v mcm.mydomain.net \
               -c mycluster \
               -u myuser \
               -j myjob \
               -mcm
# end example
```

or specify the API key on the command line:

```bash
# example using API key authentication
./backupNow.py -v mcm.mydomain.net \
               -c mycluster \
               -u myuser \
               -j myjob \
               -p xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
               -mcm
# end example
```

## Troubleshooting

* If the script seems to hang for a long time and never connects, it's likely that a firewall is blocking the connection. Try using ping, nping (port 443/tcp), etc. to validate the connection.
* If authentication fails, make sure that you have a valid user registered in Helios, MCM, or cluster (remember, SSO users are not supported).
* Make sure the user is not locked out (including in Active Directory), disabled, password expired, etc.
* If you receive timeout errors, read here: <https://github.com/cohesity/community-automation-samples/blob/main/doc/681-Upgrade-Impacts.md#api-timeouts>
* If you receive 'Too Many Requests' errors, read here: <https://github.com/cohesity/community-automation-samples/blob/main/doc/681-Upgrade-Impacts.md#api-rate-limiting>
