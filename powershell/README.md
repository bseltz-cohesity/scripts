# Cohesity REST API PowerShell Examples

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## The API Helper Module: cohesity-api-ps1

cohesity-api.ps1 contains a set of functions that make it easy to use the Cohesity REST API, including functions for authentication, making REST calls, and managing date formats.

### Basic Usage
```powershell
# source the helper module
. .\cohesity-api.ps1
# authenticate
apiauth -vip mycluster -username admin #domain defaults to 'local'
# or
apiauth -vpi mycluster -username myuser -domain mydomain #using an Active Directory user
```
### Stored Passwords
There is no parameter to provide your password! The fist time you authenticate to a cluster, you will be prompted for your password. The password will be encrypted and stored (in the user's registry on Windows or in the user's home folder on Mac/Linux). The stored password will then be used automatically so that scripts can run unattended. 

If your password changes, use apiauth with -updatePassword to prompt for the new password.
```powershell
. .\cohesity-api.ps1
apiauth -vpi mycluster -username myuser -domain mydomain -updatePassword
```
### API Calls
Once authenticated, you can make API calls. For example:
```powershell
PS /powershell> api get protectionJobs | ft id, name, environment                                 

 id name                        environment
 -- ----                        -----------
 14 VM Backup                   kVMware    
 19 SQL VM Backup               kSQL       
 22 Physical Block-Based Backup kPhysical  
 27 NAS Backup                  kGenericNas
 31 Oracle                      kPuppeteer 
562 Oracle Adapter              kOracle    

```
### Date Conversions
Cohesity stores dates in Unix Epoch Microseconds. That's the number of microseconds since midnight on Jan 1, 1970. Several conversion functions have been included to handle these dates.
```powershell
PS /Users/brianseltzer/scripts/powershell> api get protectionJobs | ft id, name, environment, creationTimeUsecs              

 id name                        environment creationTimeUsecs
 -- ----                        ----------- -----------------
 14 VM Backup                   kVMware      1533978038503713
 19 SQL VM Backup               kSQL         1533978139120648
 22 Physical Block-Based Backup kPhysical    1533978187055536
 27 NAS Backup                  kGenericNas  1533978339636513
 31 Oracle                      kPuppeteer   1533979034996328
562 Oracle Adapter              kOracle      1534238967555486

usecsToDate 1533978038503713
Saturday, August 11, 2018 5:00:38 AM

dateToUsecs 'Saturday, August 11, 2018 5:00:38 AM'                    
1533978038000000

timeAgo 24 hours                                                      
1534409454000000
``` 