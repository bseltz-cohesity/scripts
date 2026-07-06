# Multi-cluster Authentication Example for PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script provides all the command line options and functions to authenticate to multiple Cohesity clusters, directly or through Helios, using the various authentication methods available (v1 accessTokens, v2 sessions, UI login, and API keys).

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'auth-example-multi'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/devGuide/powershell/examples/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* auth-example-multi.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

## Examples

### Connect directly to a single cluster (prompt for password)

```powershell
./auth-example.ps1 -vip mycluster.mydomain.net -username admin -domain local
```

If no cached password exists, you'll be prompted to enter one, and it will be cached (encrypted) for future runs.

### Connect directly to multiple clusters

```powershell
./auth-example.ps1 -vip 'cluster1.mydomain.net','cluster2.mydomain.net' -username admin -domain local
```

`-vip` accepts a comma-separated list of clusters. The script authenticates to and reports on each one in turn.

### Connect directly to a cluster (using an Active Directory user)

```powershell
./auth-example.ps1 -vip mycluster.mydomain.net -username myuser -domain mydomain.net
```

Always use the fully qualified domain name when using Active Directory credentials.

### Connect directly to a cluster with a password inline

```powershell
./auth-example.ps1 -vip mycluster.mydomain.net -username myusername -domain mydomain.net -password 'MyP@ssw0rd'
```

### Connect without prompting for a password

Useful for unattended/scheduled scripts. If no cached password is found, authentication simply fails instead of prompting.

```powershell
./auth-example.ps1 -vip mycluster.mydomain.net -username myusername -domain mydomain.net -noPrompt
```

### Connect using an API key

```powershell
./auth-example.ps1 -vip mycluster.mydomain.net -username myApiKeyUser -useApiKey
```

When targeting multiple direct clusters, only the first one uses the API key supplied on the command line — the script clears it afterward so it isn't reused against clusters it wasn't issued for. Cache a key per cluster ahead of time if you need to hit more than one.

### Connect through Helios (all managed clusters)

```powershell
./auth-example.ps1
```

With no `-vip` or `-clusterName` specified, the script connects to the default `helios.cohesity.com`, then loops through and reports on every cluster registered in Helios.

### Connect through Helios (specific clusters)

```powershell
./auth-example.ps1 -clusterName 'cluster1','cluster2'
```

`-clusterName` accepts a comma-separated list to target specific Helios-managed clusters instead of all of them.

### Connect through Helios as a specific user

```powershell
./auth-example.ps1 -username myuser@mydomain.net -clusterName mycluster
```

The username is not used for authentication, but it is used to store/retrieve the cached API key.

### Connect through Helios On-prem / MCM (multi-cluster manager)

```powershell
./auth-example.ps1 -vip mcm.mydomain.net -helios -clusterName 'cluster1','cluster2'
```

Omit `-clusterName` to loop through all clusters managed by the on-prem MCM/Helios instance.

### Connect and impersonate a tenant organization

```powershell
./auth-example.ps1 -vip mycluster.mydomain.net -username myusername -domain mydomain.net -tenant MyTenantOrg
```

### Connect using TOTP multi-factor authentication

```powershell
./auth-example.ps1 -vip mycluster.mydomain.net -username myusername -domain mydomain.net -mfaCode 123456
```

### Connect using email-delivered MFA code

Sends an MFA code to the user's email, then prompts you to enter it.

```powershell
./auth-example.ps1 -vip mycluster.mydomain.net -username myusername -domain mydomain.net -emailMfaCode
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -helios: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM
