# Authentication Functions Explained

## Loading cohesity-api.ps1

The functions in cohesity-api.ps1 the function library are made available in your current PowerShell session or script, by "dot sourcing" the cohesity-api.ps1 file, like:

```powershell
. .\cohesity-api.ps1
```

Or in a script, to ensure that works when running the script ouside the folder where the script exists, I often do this:

```powershell
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)
```

## The apiauth function

Authentication is handled by the `apiauth` function:

```powershell
function apiauth($vip='helios.cohesity.com', 
                 $username = 'helios', 
                 $domain = 'local', 
                 $passwd = $null,
                 $password = $null,
                 $tenant = $null,
                 $regionid = $null,
                 $mfaType = 'Totp',
                 [string] $mfaCode = $null,
                 [switch] $emailMfaCode,
                 [switch] $helios,
                 [switch] $quiet, 
                 [switch] $noprompt, 
                 [switch] $updatePassword, 
                 [switch] $useApiKey,
                 [switch] $v2,
                 [boolean] $apiKeyAuthentication = $false,
                 [boolean] $heliosAuthentication = $false,
                 [boolean] $sendMfaCode = $false,
                 [boolean] $noPromptForPassword = $false)
```

## Comprehensive Authentication

The following code covers all authentication scenarios including HElios/MCM, Ccs, Multi-Tenancy API Keys, MFA, etc.

```powershell
# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][string]$region
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}
```

## Basics

As you can see, thee are a lot of options, but in its most basic form, you provide the vip, username and domain:

```powershell
apiauth -vip mycluster -username myusername -domain mydomain.net
```

## What about the password

You will notice that we did not provide a password. apiauth will use a stored password by default, so that you don't have to pass the password at the command line in clear text. If this is the first time you are authenticating with that particular vip/username/domain combination, you will be prompted for your password, and the password will be stored in secure password storage for later use. The next time you use the same combination, the stored password will be silently retrieved and used, so that scripts can be run unattended without providing a password in clear text.

The password will be stored in one of the following locations:

* In Windows: in the current user's registry under HKCU/Software/Cohesity-API
* In Linux or MacOS: in a hidden folder under the current user's home directory ~/.cohesity-api

There's also an option to store passwords in a shared password file in the directory with the scripts. This can be useful when you need to store a password for a non-interactive user (e.g. service account). The passwords in the shared file are obfuscated but pretty easy to crack so it's less secure than user-unique password storage. There is a more secure way to store a password for a non-interactive user that will be covered later.

## Updating a stored password or API key

If your password has changed, an attempt to authenticate will fail, and you will be prompted to reenter your password, but you can also preemptively update the password, using the updatePassword switch:

```powershell
. .\cohesity-api.ps1
apiauth -vip mycluster -username myusername -domain mydomain.net -updatePassword
```

or if desired, you can simply use the -password parameter:

```powershell
. .\cohesity-api.ps1
apiauth -vip mycluster -username myusername -domain mydomain.net -password MyPassW0rd
```

## Password Store and Import

Normally, when you want scripts to run unattended, you need to store the password (or API key) in encrypted storage, and to do that, you log with the Windows (or Linux or Mac) account and simply run a script. You will be prompted for your API password and the password will be stored. Subsequent script runs will silently retrieve the password.

However, you may be running scripts via the Windows Task Scheduler or as part of a SQL Agent job, using a functional service account that does not have the right to logon interactively. In this case, you need to help the user get the password stored. This can be done by having an interactive user store the password using `storePasswordForUser`, and then the non interactive user can run `importStoredPassword` to retrieve and store the password. Like so:

Note: the below examples use the internal function names in cohesity-api.ps1, which assumes that you sourced cohesity-api.ps1 as mentioned above. There is a script for storing and importing passwords here: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/storeAndImportPassword>

Please use the script rather than these functions. The below is just for completeness of the discussion.

```powershell
# interactive user stores the password (or API Key)
PS ~/scripts/powershell> storePasswordForUser -vip mycluster -username thatuser -domain mydomain.net
Enter password for thatuser at mycluster: ********
Confirm password for thatuser at mycluster: ********

Password stored. Use key 45355232094434 to unlock

# non-interactive user retrieves the password
PS ~/scripts/powershell> importStoredPassword -vip mycluster -username thatuser -domain mydomain.net -key 45355232094434  
Password imported successfully

# or, non-interactive user retrieves the API Key
PS ~/scripts/powershell> importStoredPassword -vip mycluster -username thatuser -domain mydomain.net -key 45355232094434 -useApiKey
Password imported successfully
```

## Using a Shared Password File

In some cases it can be challenging to store the API password for a service account to use, in which case it might be easier (albeit less secure) to store the API password in a file. You can store the password in a file, in the same folder as the script(s) that you want to run.

Note: the below examples use the internal function names in cohesity-api.ps1, which assumes that you sourced cohesity-api.ps1 as mentioned above. There is a script for storing passwords in a file here: <https://github.com/cohesity/community-automation-samples/tree/main/powershell/storePasswordInFile>.

Please use the script rather than these functions. The below is just for completeness of the discussion.

```powershell
storePasswordInFile -vip mycluster -username myusername -domain mydomain.net
```

The password will be stored (obfuscated) in a file in the current folder.

## About the VIP

The VIP can be any of the following:

* The DNS name of the cluster you want to connect to
* The VIP or node IP of the cluster you want to connect to
* <helios.cohesity.com>
* The IP or DNS name of a Helios On Prem instance
* localhost:portnum if connecting via an SSH tunnel

## About Usernames and Domains

By default, domain is set to 'local' so you can simply:

```powershell
apiauth -vip mycluster -username admin
```

Active directory domains must be fully qualified, so you must:

```powershell
apiauth -vip mycluster -username myusername -domain mydomain.net  # mydomain.net is correct
```

not

```powershell
apiauth -vip mycluster -username myusername -domain mydomain  # mydomain is wrong
```

You can also combine domain\username, like:

```powershell
apiauth -vip mycluster -username mydomain.net\myusername  # mydomain.net is correct
```

but again:

```powershell
apiauth -vip mycluster -username mydomain\myusername  # mydomain is wrong
```

## On Helios and API Keys

Helios does not use usernames and passwords when authenticating to its API. Insead, we have to use an API key.

To acquire an API key:

* log onto Helios with your web browser
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.

The apiauth function treats the API key like a password, and stores it in secure password storage. Although authentication with an API key requires no username or domain, the apiauth function uses these to store and retrieve the password, so we can still use a username and domain to store API keys for multiple Helios accounts.

That said, <helios.cohesity.com> is the default VIP, and 'helios' is the default username. So to authenticate to Helios, you can simply type:

```powershell
apiauth
```

Enter the API key when prompted, and the API key will be stored in secure password storage as the combination helios.cohesity.com/helios/local.

If you have more than one Helios account, you can differentiate with a username like:

```powershell
apiauth -username myuser@mydomain.net
```

Note that the username doesn't really matter for authentication to work (it could be completely bogus), but what's important is that the API key will be stored as helios.cohesity.com/myuser@mydomain.net/local

## Selecting a Helios Connected Cluster to Work With

After being successfully authenticated to Helios, you can select a cluster to operate on. To see the list of Helios connected clusters, type:

```powershell
heliosClusters
```

And to connect to a specific cluster:

```powershell
heliosCluster myClusterName
```

then you can perform API calls to that cluster as usual.

***Note***: Not all scripts have been updated to connect through Helios, but it's easy to do. Please see the script <https://github.com/cohesity/community-automation-samples/blob/main/reports/powershell/backupSummaryReport/backupSummaryReport.ps1> to see an example that uses a wide range of authentication options.

## Using API Keys for Clusters and Helios On Prem

You can also use an API key to authenticate to a Cohesity cluster or HElios On Prem instance.

To acquire an API key:

* log onto the cluster with your web browser
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again).

Then you can do this:

```powershell
apiauth -vip mycluster -useApiKey
```

or better yet, for clarity of password storage:

```powershell
apiauth -vip mycluster -username myusername -domain mydomain.net -useApiKey
```

## On Organizations (Tenants)

You can log on as a cluster user and impersonate a tenant:

```powershell
apiauth -vip mycluster -username admin -domain local -tenant ORG1
```

or you can log on as a tenant user:

```powershell
apiauth -vip mycluster -username thisuser@ORG1 -domain local
```

## Connecting to Ccs

Ccs is accessed via helios.cohesity.com but it's helpful to set the region ID, so there's a regionId parameter:

```powershell
apiauth -username myusername@mydomain.net -regionId us-east-2
```

## Context Switching

Context switching allows you to authenticate to multiple Cohesity clusters, and switch back and forth without having to re-authenticate (which can take a few seconds and generates a new auth token each time). To perform context switching, you authenticate to a Cohesity cluster, store that context in a variable using `getContext`, authenticate to another cluster and store that context, then you can use `setContext` to switch contexts. For example:

```powershell
# authenticate to cluster1
PS ~/scripts/powershell> apiauth cluster1 admin
Connected!

# store the context in a variable
PS ~/scripts/powershell> $cluster1Context = getContext

# authenticate to cluster2
PS ~/scripts/powershell> apiauth cluster2 admin
Connected!

# store the context in a variable
PS ~/scripts/powershell> $cluster2Context = getContext

# switch context to cluster1
PS ~/scripts/powershell> setContext $cluster1Context
PS ~/scripts/powershell> (api get cluster).name
CLUSTER1

# switch context to cluster2
PS ~/scripts/powershell> setContext $cluster2Context
PS ~/scripts/powershell> (api get cluster).name
CLUSTER2
```

## Multifactor Authentication (MFA)

As of 2021-12-07 MFA is supported. Note that MFA applies to local Cohsity accounts. For Active Directory and SSO accounts, MFA is provided by those services. Also note that to run scripts unattended using an MFA protected account, API Key authentication can be used, because it is not subject to MFA.

### Using Totp MFA

```powershell
PS ~/scripts/powershell> apiauth -vip mycluster -username myuser -mfaCode 057476
Connected!
```

### Using Email MFA

```powershell
PS ~/scripts/powershell> apiauth -vip mycluster -username myuser -emailMfaCode  
Enter emailed MFA code: 433192
Connected!
```

### Putting it All Together

Many existing scripts have not yet been updated to support all of the above options, but it's pretty straightforward to update any script to support a wide array of authentication options. The basic prototype is:

```powershell
### process commandline arguments
[CmdletBinding()]
param (
   [Parameter()][string]$vip = 'helios.cohesity.com',
   [Parameter()][string]$username = 'helios',
   [Parameter()][string]$domain = 'local',
   [Parameter()][switch]$useApiKey,
   [Parameter()][string]$password = $null,
   [Parameter()][switch]$mcm,
   [Parameter()][string]$mfaCode = $null,
   [Parameter()][switch]$emailMfaCode,
   [Parameter()][string]$clusterName = $null
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region

### select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit
}

# do some stuff with the connected cluster
# $jobs = api get protectionJobs
```
