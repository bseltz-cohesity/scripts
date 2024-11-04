# Cohesity PowerShell Scripts

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This repository contains many examples of how to automate Cohesity using PowerShell. Common to each example is a function library that makes it easy to authenticate and make api calls. Below are details of this library.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory:

```powershell
# Download Commands
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Function library - cohesity-api.ps1

The function library, cohesity-api.ps1 provides a suite of functions to make it easier to use the Cohesity api. To use the library, we can source (otherwise known as dot sourcing) the library within a PowerShell session or within a script, like so:

```powershell
. ./cohesity-api.ps1
```

Notice the extra dot in the command above (it's 'dot' 'space' 'dot' 'slash'). This is called sourcing (or dot sourcing) a script. It brings the contents (functions) of the file into the current session or script. After sourcing the library, we can start using its functions.

### Authentication

```powershell
apiauth -vip mycluster -username myusername -domain mydomain.net
```

This command authenticates with the cluster and retrieves an access token so we can make authenticated api calls. When the command is run, the user is prompted for their password, and the password will be stored, encrypted, so that scripts can be run unattended, without being prompted for the password again.

If the user's password is changed in Active Directory or in Cohesity, the stored password can be updated using the -updatepassword parameter, for example:

```powershell
apiauth -vip mycluster -username myusername -domain mydomain.net -updatepassword
```

apiauth supports the following parameters:

* -vip: FQDN or IP Address of the Cohesity cluster to connect to
* -username: username to connect to Cohesity
* -domain: (optional) Active Directory domain name of user (defaults to mydomain.net)
* -pwd: (optional) hard code the password (not recommended) the password will not be stored
* -password: (optional) hard code the password (not recommended) the password will not be stored
* -updatepassword: (optional) prompt for password and overwrite the stored password
* -quiet: (optional) by default a successfull authentication will report Connected!
* -noprompt: (optional) will not prompt user for password and will exit if password is not already stored
* -helios: (optional) will use Helios api key for authentication

You can use various username formats like:

```powershell
apiauth -vip mycluster -username mydomain.net\myusername
```

or

```powershell
apiauth -vip mycluster -username myusername@mydomain.net
```

### Making API Calls

Once authenticated, we can make api calls:

```powershell
$jobs = api get protectionJobs
$jobs | ft

   id name              environment    policyId                            viewBoxId parentSourceId sourceIds            sta
                                                                                                                         rtT
                                                                                                                         ime
   -- ----              -----------    --------                            --------- -------------- ---------            ---
    7 VM Backup         kVMware        770535285385794:1544976774290:5             5              1 {29, 30, 1757}       @{h
   12 Infrastructure    kVMware        770535285385794:1544976774290:5             5              1 {121, 36, 39, 33...} @{h
   35 Oracle Adapter    kOracle        770535285385794:1544976774290:377           5             64 {61}                 @{h
 6222 File-Based Backup kPhysicalFiles 770535285385794:1544976774290:32789         5             60 {98}                 @{h
 8028 SQL Backup        kSQL           770535285385794:1544976774290:377           5             46 {31}                 @{h
31495 Generic NAS       kGenericNas    770535285385794:1544976774290:25            5             85 {1759}               @{h
32207 GarrisonToVE2     kVMware        770535285385794:1544976774290:32206         5              1 {1708, 1709}         @{h
32392 CentOS3           kPhysical      770535285385794:1544976774290:5             5             60 {98}                 @{h
32431 VE2toGarrison     kVMware        698796861248052:1544906007391:10772         5           1718 {1719, 1720}         @{h
32793 Scripts Backup    kView          770535285385794:1544976774290:32206         5            102 {116}                @{h
35465 RMAN Backup       kPuppeteer     770535285385794:1544976774290:25            5            102 {1741}               @{h
39282 Ubuntu            kPhysical      770535285385794:1544976774290:25            5             60 {1755}               @{h
51831 NetAppJob         kNetapp        770535285385794:1544976774290:25            5           1760 {1761}               @{h
54524 CloudSpin         kVMware        770535285385794:1544976774290:25            5              1 {2111}               @{h
```

The api function supports the following parameters:

* -method: get, post, put, or delete
* -url: see below for details
* -data: (optional) data structure for posts and puts, see below

The url parameter accepts the tail of the api endpoint url. For example, in the example above, the full url is <https://mycluster/irisservices/api/v1/public/protectionJobs> but the api function only requires the protectionJobs portion of the url.

For non-public api calls, include a leading slash, e.g. api get /backupjobs

The data parameter accepts a nested hash-table of parameters, which are converted to JSON and sent allow with post or put api calls. For example:

```powershell
$jobdata = @{
   'runType' = 'kRegular'
}
```

Please review the example scripts for data structures that are appropriate for various workflows.

### Date Functions

Cohesity stores datetimes in UNIX microseconds, which is the number of microseconds since midnight, January 1st, 1970. cohesit-api.ps1 provides several functions to handle this date format.

```powershell
dateToUsecs '2019-04-15 13:20:15'
1555348815000000

usecsToDate 1555348815000000
Monday, April 15, 2019 1:20:15 PM

timeAgo 1 month
1552714478000000

usecsToDate 1552714478000000
Saturday, March 16, 2019 1:34:38 AM

timeAgo 1 week
1554737702000000

usecsToDate 1554737702000000
Monday, April 8, 2019 11:35:02 AM
```

### Working with Helios

If your Cohesity cluster is connected to Helios, you can connect to Helios for API access to your Cohesity cluster. First, log onto the Helios web UI and go to Access Management and create an API Key (copy the new key somewhere because you can only see it one time in the UI).

Next, let's authenticate to Helios in PowerShell:

```powershell
apiauth -helios
```

When prompted for your password, paste the API key and press enter. Once connected, we need to select one of your helios-connected clusters for API operations. To see the list of clusters, type:

```powershell
heliosCluster
```

```text
name                     clusterId softwareVersion
----                     --------- ---------------
azure-ce          3189861069838537 6.4.1a_release-20200127_bd2f17b1
BKDataRep01       3245772218955543 6.4.1_release-20191219_aafe3274
BKDRRep02         5860211595354073 6.4.1_release-20191219_aafe3274
Cluster-01        8535175768906402 6.4.1a_release-20200127_bd2f17b1
co1               5405667779793465 6.3.1a_release-20190806_1ea88a62
```

Then select which cluster to use:

```powerShell
heliosCluster Cluster-01
```

You can then make API calls to that cluster, through helios, as if you were connected directly to that cluster.

### Managing Passwords

As mentioned above, if you want to update the stored password, you can type:

```powershell
. ./cohesity-api.ps1
apiauth -vip mycluster -username myusername -domain mydomain.net -updatepassword
```

You can also use the apipwd function which has some additional functionality:

```powershell
apipwd -vip mycluster -username myusername -domain mydomain.net
```

When passwords are stored, they are stored for the currently logged in OS user. In Linux, the encrypted password is stored under the currently logged in OS user's home directory. In Windows, the encrypted password is stored under the currently logged in OS user's registry.

If you are setting up a script to run unattended by another user who is not currently logged in, we must store the password while logged in as that user. This is common in Windows environments where scripts may be run by the SQL Agent account. To store the password as another Windows user, you can type:

```powershell
apipwd -vip mycluster -username myusername -domain mydomain.net -asUser
```

You will be prompted for the credentials of another Windows user, and then a new PowerShell window will open and prompt you for the api password.

### Using a Password File

In some cases it can be challenging to store the API password for a service account to use, in which case it might be easier (albeit less secure) to store the API password in a file. You can store the password in a file, in the same folder as the script(s) that you want to run, like so:

```powershell
. ./cohesity-api.ps1
storePasswordInFile -vip ve2 -username myusername -domain mydomain.net
```

The password will be stored (obfuscated) in a file in the current folder.

### Self Updater

You can get the current version information of this file like so:

```powershell
. ./cohesity-api.ps1
cohesityAPIversion
```

and get the latest version:

```powershell
. ./cohesity-api.ps1
cohesityAPIversion -update
```

Please exit and restart PowerShell after updating.
