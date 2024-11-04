# Get Set Export and Import Feature Flags using  PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script gets, sets, exports and imports feature flags.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'featureFlags'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [featureFlags.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/featureFlags/featureFlags.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

### Setting a Feature Flag

Non-UI feature:

```powershell
# example
./featureFlags.py -vip mycluster `
                  -username myuser `
                  -domain mydomain.net ` 
                  -flagName magneto_master_enable_read_replica `
                  -reason 'read replica'
# end example
```

UI feature:

```powershell
# example
./featureFlags.py -vip mycluster `
                  -username myuser `
                  -domain mydomain.net ` 
                  -flagName some_feature `
                  -reason 'cool feature' `
                  -isUiFeature
# end example
```

### Clearing a Feature Flag

Non-UI feature:

```powershell
# example
./featureFlags.py -vip mycluster `
                  -username myuser `
                  -domain mydomain.net ` 
                  -flagName some_feature `
                  -clear
# end example
```

UI Feature:

```powershell
# example
./featureFlags.py -vip mycluster `
                  -username myuser `
                  -domain mydomain.net ` 
                  -flagName some_feature `
                  -isUiFeature `
                  -clear
# end example
```

### Importing a List of Feature Flags

To import feature flags from a CSV file:

```powershell
# example
./featureFlags.py -vip mycluster `
                  -username myuser `
                  -domain mydomain.net ` 
                  -importFile myfile.csv
# end example
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -tenant: (optional) impersonate a multitenancy org
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -flagName: (optional) name of feature flag to set
* -reason: (optional) reason for setting the flag
* -isUiFeature: (optional) specify that feature flag is a UI feature (false if omitted)
* -clear: (optional) remove the feeature flag
* -importFile: (optional) name of file to import
