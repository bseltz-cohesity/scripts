# Isilon API Function Library for PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a function library for Isilon API that uses session cookie authentication with CSRF protection. This is not for the Cohesity API but is useful when connecting to Isilon API.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/isilon-api/isilon-api.ps1").content | Out-File -Force isilon-api.ps1; (Get-Content isilon-api.ps1) | Set-Content isilon-api.ps1
# End Download Commands
```

## Function library - isilon-api.ps1

The function library, isilon-api.ps1 provides a suite of functions to make it easier to use the Isilon api. To use the library, we can source (or dot) the library within a PowerShell session or within a script, like so:

```powershell
. ./isilon-api.ps1
```

Notice the extra dot in the command above (it's 'dot' 'space' 'dot' 'slash'). This is called sourcing (or dot sourcing) a script. It brings the contents (functions) of the file into the current session or script. After sourcing the library, we can start using its functions.

### Authentication

```powershell
isilonAuth -endpoint myendpoint -username myusername
```

This command establishes authentication with the API so we can make authenticated api calls. When the command is run, the user is prompted for their password, and the password will be stored, so that scripts can be run unattended, without being prompted for the password again.

isilonAuth supports the following parameters:

* -endpoint: endpoint to connect to the API
* -username: username to connect to the API
* -password: (optional) hard code the password (not recommended) the password will be stored

### Making API Calls

Once authenticated, we can make api calls:

```powershell
isilonApi get "/platform/1/license/licenses"
```

The isilonApi function supports the following parameters:

* -method: get, post, put, or delete
* -uri: the tail of the URL (not including 'https://address:port')
* -data: (optional) data structure for posts and puts, see below

The data parameter accepts a nested hash-table of parameters, which are converted to JSON and sent allow with post or put api calls. For example:

```powershell
$jobdata = @{
   'runType' = 'kRegular'
}
```

### Date Functions

Some APIs store datetimes in UNIX microseconds, which is the number of microseconds since midnight, January 1st, 1970. cohesit-api.ps1 provides several functions to handle this date format.

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
