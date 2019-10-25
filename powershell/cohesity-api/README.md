# Cohesity PowerShell Scripts

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This repository contains many examples of how to automate Cohesity using PowerShell. Common to each example is a function library that makes it easy to authenticate and make api calls. Below are details of this library.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Function library - cohesity-api.ps1

The function library, cohesity-api.ps1 provides a suite of functions to make it easier to use the Cohesity API. To use the library, we can source (or dot) the library within a PowerShell session or within a script, like so:

```powershell
. ./cohesity-api.ps1
```

notice the extra dot in the command above. That syntax loads the contents of cohesity-api.ps1 into the current session or script. After sourcing the library, we can start using its functions.

### Authentication

```powershell
apiauth -vip mycluster -username myusername -domain mydomain.net
```

This command authenticates with the cluster and retrieves an access token for use with subsequent api calls. When the command is run, the user is prompted for their password, and the password will be stored, encrypted, so that scripts can be run unattended, without being prompted for the password again.

If the user's password is changed in Active Directory or in Cohesity, the stored password can be updated using the -updatepassword parameter, for example:

```powershell
apiauth -vip mycluster -username myusername -domain mydomain.net -updatepassword
```

apiauth supports the following parameters:

* -vip: FQDN or IP Address of the Cohesity cluster to connect to
* -username: username to connect to Cohesity
* -domain: (optional) Active Directory domain name of user (defaults to local)
* -prompt: (optional) prompt for password and do not store it (default is to use stored password)
* -updatepassword: (optional) prompt for password and overwrite the stored password
* -quiet: (optional) by default a successfull authentication will report Connected!

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
   'runType' = "kRegular"
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
