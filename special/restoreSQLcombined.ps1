### v2019-09-19 - added support for replicated recoveries
### usage (Cohesity 5.x): ./restore-SQL.ps1 -vip bseltzve01 -username admin -domain local -sourceServer sql2012 -sourceDB proddb -targetServer w2012a -targetDB bseltz-test-restore -overWrite -mdfFolder c:\sqldata -ldfFolder c:\sqldata\logs -ndfFolder c:\sqldata\ndf

### usage (Cohesity 6.x): ./restore-SQL.ps1 -vip bseltzve01 -username admin -domain local -sourceServer sql2012 -sourceDB cohesitydb -targetDB cohesitydb-restore -overWrite -mdfFolder c:\SQLData -ldfFolder c:\SQLData\logs -ndfFolders @{'*1.ndf'='E:\sqlrestore\ndf1'; '*2.ndf'='E:\sqlrestore\ndf2'}
###                        ./restore-SQL.ps1 -vip bseltzve01 -username admin -domain local -sourceServer sql2012 -sourceDB cohesitydb -targetDB cohesitydb-restore -overWrite -mdfFolder c:\SQLData -ldfFolder c:\SQLData\logs -logTime '2019-01-18 03:01:15'

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,          #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,     #username (local or AD)
    [Parameter()][string]$domain = 'local',              #local or AD domain
    [Parameter(Mandatory = $True)][string]$sourceServer, #protection source where the DB was backed up
    [Parameter(Mandatory = $True)][string]$sourceDB,     #name of the source DB we want to restore
    [Parameter()][string]$targetServer = $sourceServer,  #where to restore the DB to
    [Parameter()][string]$targetDB = $sourceDB,          #desired restore DB name
    [Parameter()][switch]$overWrite,                     #overwrite existing DB
    [Parameter()][string]$mdfFolder,                     #path to restore the mdf
    [Parameter()][string]$ldfFolder = $mdfFolder,        #path to restore the ldf
    [Parameter()][hashtable]$ndfFolders,                 #paths to restore the ndfs (requires Cohesity 6.0x)
    [Parameter()][string]$ndfFolder,                     #single path to restore ndfs (Cohesity 5.0x)
    [Parameter()][string]$logTime,                       #date time to replay logs to e.g. '2019-01-20 02:01:47'
    [Parameter()][switch]$wait,                          #wait for completion
    [Parameter()][string]$targetInstance = 'MSSQLSERVER', #SQL instance name on the targetServer
    [Parameter()][switch]$latest,
    [Parameter()][switch]$noRecovery,
    [Parameter()][switch]$progress
)

### handle 6.0x alternate secondary data file locations
if($ndfFolders){
    if($ndfFolders -is [hashtable]){
        $secondaryFileLocation = @()
        foreach ($key in $ndfFolders.Keys){
            $secondaryFileLocation += @{'filePattern' = $key; 'targetDirectory' = $ndfFolders[$key]}
        }
    }
}else{
    $secondaryFileLocation = @()
}

### source the cohesity-api helper code
# . . . . . . . . . . . . . . . . . . . . . . . .
#  Unofficial PowerShell Module for Cohesity API
#   version 0.12 - Brian Seltzer - Oct 2019
# . . . . . . . . . . . . . . . . . . . . . . . .
#
# 0.6 - Consolidated Windows and Unix versions - June 2018
# 0.7 - Added saveJson, loadJson and json2code utility functions - Feb 2019
# 0.8 - added -prompt to prompt for password rather than save - Mar 2019
# 0.9 - added setApiProperty / delApiProperty - Apr 2019
# 0.10 - added $REPORTAPIERRORS constant - Apr 2019
# 0.11 - added storePassword function and username parsing - Aug 2019
# 0.12 - begrudgingly added -password to apiauth function - Oct 2019
#
# . . . . . . . . . . . . . . . . . . . . . . . . 

$REPORTAPIERRORS = $true

# platform detection and prerequisites
if ($PSVersionTable.Platform -eq 'Unix') {
    $UNIX = $true
    $CONFDIR = '~/.cohesity-api'
    if ($(Test-Path $CONFDIR) -eq $false) { $quiet = New-Item -Type Directory -Path $CONFDIR}
}
else {
    $UNIX = $false
    $WEBCLI = New-Object System.Net.WebClient;

    # ignore unsigned certificates
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true }
    Add-Type @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            ServicePointManager.ServerCertificateValidationCallback += 
                delegate
                (
                    Object obj, 
                    X509Certificate certificate, 
                    X509Chain chain, 
                    SslPolicyErrors errors
                )
                {
                    return true;};}}
"@
    [ServerCertificateValidationCallback]::Ignore();
}

# authentication function
function apiauth($vip, $username, $domain, $password, [switch] $prompt, [switch] $updatepassword, [switch] $quiet){

    if(-not $vip){
        write-host 'VIP: ' -foregroundcolor green -nonewline
        $vip = Read-Host
        if(-not $vip){write-host 'vip is required' -foregroundcolor red; break}
    }
    if(-not $username){
        write-host 'Username: ' -foregroundcolor green -nonewline
        $username = Read-Host
        if(-not $username){write-host 'username is required' -foregroundcolor red; break}
    }
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    if($username.Contains('@')){
        $username, $domain = $username.Split('@')
    }
    if($updatepassword){
        $updatepw = '-updatePassword'
    }else{ 
        $updatepw = $null
    }
    if($prompt){
        $pr = '-prompt'
    }else{
        $pr = $null
    }

    $global:VIP = $vip
    $global:APIROOT = 'https://' + $vip + '/irisservices/api/v1'
    $HEADER = @{'accept' = 'application/json'; 'content-type' = 'application/json'}
    $url = $APIROOT + '/public/accessTokens'

    try {
        if($UNIX){
        $auth = Invoke-RestMethod -Method Post -Uri $url  -Header $HEADER -Body $(
            ConvertTo-Json @{
                'domain' = $domain; 
                'password' = $(if($password){$password}else{getpwd -vip $vip -username $username -domain $domain -prompt $pr -updatePassword $updatepw}); 
                'username' = $username
            }) -SkipCertificateCheck
        $global:CURLHEADER = "authorization: $($auth.tokenType) $($auth.accessToken)"
        }else{
            $auth = Invoke-RestMethod -Method Post -Uri $url  -Header $HEADER -Body $(
                ConvertTo-Json @{
                    'domain' = $domain; 
                    'password' = $(if($password){$password}else{getpwd $vip $username -domain $domain -prompt $pr -updatePassword $updatepw}); 
                    'username' = $username
                })
            $WEBCLI.Headers['authorization'] = $auth.tokenType + ' ' + $auth.accessToken;
        }
        $global:AUTHORIZED = $true
        $global:HEADER = @{'accept' = 'application/json'; 
            'content-type' = 'application/json'; 
            'authorization' = $auth.tokenType + ' ' + $auth.accessToken
        }
        if(!$quiet){ write-host "Connected!" -foregroundcolor green }
    }
    catch {
        $global:AUTHORIZED = $false
        if($REPORTAPIERRORS){
            if($_.ToString().contains('"message":')){
                write-host (ConvertFrom-Json $_.ToString()).message -foregroundcolor yellow
            }else{
                write-host $_.ToString() -foregroundcolor yellow
            }
        }
    }
}

# api call function
$methods = 'get', 'post', 'put', 'delete'
function api($method, $uri, $data){
    if (-not $global:AUTHORIZED){ 
        if($REPORTAPIERRORS){
            write-host 'Please use apiauth to connect to a cohesity cluster' -foregroundcolor yellow
        } 
    }else{
        if (-not $methods.Contains($method)){
            if($REPORTAPIERRORS){
                write-host "invalid api method: $method" -foregroundcolor yellow
            }
            break
        }
        try {
            if ($uri[0] -ne '/'){ $uri = '/public/' + $uri}
            $url = $APIROOT + $uri
            $body = ConvertTo-Json -Depth 100 $data
            if ($UNIX){
                $result = Invoke-RestMethod -Method $method -Uri $url -Body $body -Header $HEADER  -SkipCertificateCheck
            }else{
                $result = Invoke-RestMethod -Method $method -Uri $url -Body $body -Header $HEADER
            }
            return $result
        }
        catch {
            if($REPORTAPIERRORS){
                if($_.ToString().contains('"message":')){
                    write-host (ConvertFrom-Json $_.ToString()).message -foregroundcolor yellow
                }else{
                    write-host $_.ToString() -foregroundcolor yellow
                }
            }                
        }
    }
}

# file download function
function fileDownload($uri, $fileName){
    if (-not $global:AUTHORIZED){ write-host 'Please use apiauth to connect to a cohesity cluster' -foregroundcolor yellow; break }
    try {
        if ($uri[0] -ne '/'){ $uri = '/public/' + $uri}
        $url = $APIROOT + $uri
        if ($UNIX){
            curl -k -s -H "$global:CURLHEADER" -o "$fileName" "$url"
        }else{
            $WEBCLI.DownloadFile($url, $fileName)
        } 
    }
    catch {
        $_.ToString()
        if($_.ToString().contains('"message":')){
            write-host (ConvertFrom-Json $_.ToString()).message -foregroundcolor yellow
        }else{
            write-host $_.ToString() -foregroundcolor yellow
        }                
    }
}

# terminate authentication
function apidrop([switch] $quiet){
    $global:AUTHORIZED = $false
    $global:HEADER = ''
    if(!$quiet){ write-host "Disonnected!" -foregroundcolor green }
}

# manage secure password
if ($UNIX) {

    function Create-AesManagedObject($key, $IV) {
        $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
        $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
        $aesManaged.BlockSize = 128
        $aesManaged.KeySize = 256
        if ($IV) {
            if ($IV.getType().Name -eq "String") {
                $aesManaged.IV = [System.Convert]::FromBase64String($IV)
            }
            else {
                $aesManaged.IV = $IV
            }
        }
        if ($key) {
            if ($key.getType().Name -eq "String") {
                $aesManaged.Key = [System.Convert]::FromBase64String($key)
            }
            else {
                $aesManaged.Key = $key
            }
        }
        $aesManaged
    }
    function Create-AesKey() {
        $aesManaged = Create-AesManagedObject
        $aesManaged.GenerateKey()
        [System.Convert]::ToBase64String($aesManaged.Key)
    }

    function Encrypt-String($key, $unencryptedString) {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($unencryptedString)
        $aesManaged = Create-AesManagedObject $key
        $encryptor = $aesManaged.CreateEncryptor()
        $encryptedData = $encryptor.TransformFinalBlock($bytes, 0, $bytes.Length);
        [byte[]] $fullData = $aesManaged.IV + $encryptedData
        $aesManaged.Dispose()
        [System.Convert]::ToBase64String($fullData)
    }

    function Decrypt-String($key, $encryptedStringWithIV) {
        $bytes = [System.Convert]::FromBase64String($encryptedStringWithIV)
        $IV = $bytes[0..15]
        $aesManaged = Create-AesManagedObject $key $IV
        $decryptor = $aesManaged.CreateDecryptor();
        $unencryptedData = $decryptor.TransformFinalBlock($bytes, 16, $bytes.Length - 16);
        $aesManaged.Dispose()
        [System.Text.Encoding]::UTF8.GetString($unencryptedData).Trim([char]0)
    }

    function getpwd($vip, $username, $domain, $prompt, $updatePassword) {

        if ($null -eq $domain) { $domain = 'local'}
        $keyName = $vip + ':' + $domain + ':' + $username
        $keyFile = "$CONFDIR/$keyName"
        $storedPassword = $null
        $key = $null
        #get the encrypted password if it exists
        if ((Test-Path $keyFile) -eq $True) {
            $key, $storedPassword = get-content $keyFile
        }
        if ($null -ne $updatePassword -or $null -ne $prompt) { $storedPassword = $null }
        If (($null -ne $storedPassword) -and ($storedPassword.Length -ne 0) -and ($null -ne $key)) {
            $encryptedPassword = $storedPassword
            $clearTextPassword = Decrypt-String $key $encryptedPassword
            #else prompt the user for the password and store it in CONFDIR/keyFile for next time    
        }
        else {
            $secureString = Read-Host -Prompt "Enter password for $username at $vip" -AsSecureString
            $clearTextPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString))
            if($null -eq $prompt){
                $key = Create-AesKey
                $key | Out-File $keyFile
                $encryptedPassword = Encrypt-String $key $clearTextPassword
                $encryptedPassword | Out-File $keyFile -Append
            }
        }
    
        return $clearTextPassword
    }
}else{
    function getpwd($vip, $username, $domain, $prompt, $updatePassword){

        $keyName = $vip + ':' + $domain + ':' + $username
        $registryPath = 'HKCU:\Software\Cohesity-API'
        $encryptedPasswordText = ''
        # get the encrypted password from the registry if it exists
        $storedPassword = Get-ItemProperty -Path "$registryPath" -Name "$keyName" -ErrorAction SilentlyContinue
        if($null -ne $updatepassword -or $null -ne $prompt){ $storedPassword = $null }
        If (($null -ne $storedPassword) -and ($storedPassword.Length -ne 0)) {
            $encryptedPasswordText = $storedPassword.$keyName
            $securePassword = $encryptedPasswordText  | ConvertTo-SecureString
    
        # else prompt the user for the password and store it in the registry for next time    
        }else{
            $securePassword = Read-Host -Prompt "Enter password for $username at $vip" -AsSecureString
            $encryptedPasswordText = $securePassword | ConvertFrom-SecureString
            if($null -eq $prompt){
                if(!(Test-Path $registryPath)){
                    New-Item -Path $registryPath -Force | Out-Null
                }
                Set-ItemProperty -Path "$registryPath" -Name "$keyName" -Value "$encryptedPasswordText"
            }
        }        
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }    
}

# store password function
function storePassword($vip, $username, $domain){
    if(-not $domain){
        if($username.Contains('\')){
            $domain, $username = $username.Split('\')
        }
        if($username.Contains('@')){
            $username, $domain = $username.Split('@')
        }
    }
    $pw = getpwd -vip $vip -username $username -domain $domain -updatePassword $true
    $securePassword = Read-Host -Prompt "Re-enter password for $username at $vip" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $unsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    if($pw -ne $unsecurePassword){
        write-host "Passwords do not match. Try again:" -ForegroundColor Yellow
        storePassword -vip $vip -username $username -domain $domain 
    }            
}

# date functions
function timeAgo([int64] $age, [string] $units){
    $currentTime = ([Math]::Floor([decimal](Get-Date(Get-Date).ToUniversalTime()-uformat "%s")))*1000000
    $secs=@{'seconds'= 1; 'sec'= 1; 'secs' = 1;
            'minutes' = 60; 'min' = 60; 'mins' = 60;
            'hours' = 3600; 'hour' = 3600; 
            'days' = 86400; 'day' = 86400;
            'weeks' = 604800; 'week' = 604800;
            'months' = 2628000; 'month' = 2628000;
            'years' = 31536000; 'year' = 31536000 }
    $age = $age * $secs[$units.ToLower()] * 1000000
    return [int64] ($currentTime - $age)
}

function usecsToDate($usecs){
    $unixTime=$usecs/1000000
    [datetime]$origin = '1970-01-01 00:00:00'
    return $origin.AddSeconds($unixTime).ToLocalTime()
}

function dateToUsecs($datestring){
    if($datestring -isnot [datetime]){ $datestring = [datetime] $datestring }
    $usecs =  ([Math]::Floor([decimal](Get-Date($datestring).ToUniversalTime()-uformat "%s")))*1000000
    $usecs
}

# developer tools
function saveJson($object, $jsonFile = './debug.json'){
    $object | ConvertTo-Json -Depth 99 | out-file -FilePath $jsonFile
}

function loadJson($jsonFile = './debug.json'){
    return Get-Content $jsonFile | ConvertFrom-Json
}

function json2code($json = '', $jsonFile = '', $psFile = 'myObject.ps1'){

    if($jsonFile -ne ''){
        $json = (Get-Content $jsonFile) -join "`n"
    }

    $json = $json | ConvertFrom-Json | ConvertTo-Json -Depth 99
    
    $pscode = ''
    foreach ($line in $json.split("`n")) {

        # preserve end of line character
        $finalEntry = $true
        if ($line[-1] -eq ',') {
            $finalEntry = $false
            $line = $line -replace ".$"
        }
        
        # key value delimiter :
        $key, $value = $line.split(':', 2)

        # line is braces only
        $key = $key.Replace('{', '@{').Replace('[','@(').Replace(']', ')')

        if ($value) {
            $value = $value.trim()

        # value is quoted text
            if ($value[0] -eq '"') {
                $line = "$key = $value"
            }

        # value is opening { brace
            elseif ('{' -eq $value) {
                $value = $value.Replace('{', '@{')
                $line = "$key = $value"
            }
        
        # value is opening [ list
            elseif ('[' -eq $value) {
                $value = $value.Replace('[', '@(')
                $line = "$key = $value"                  
            }

        # empty braces
            elseif ('{}' -eq $value) {
                $value = '@{}'
                $line = "$key = $value"
            }
        
        # empty list
            elseif ('[]' -eq $value) {
                $value = '@()'
                $line = "$key = $value"
            }

        # value is opening ( list
            elseif ('[' -eq $value) {
                $value = $value.Replace('[', '@(')
                $line = "$key = $value"
            }

        # value is a boolean
            elseif ($value -eq 'true') {
                $line = "$key = " + '$true'
            }

            elseif ($value -eq 'false') {
                $line = "$key = " + '$false'
            }

        # null
            elseif ($value -eq 'null') {
                $line = "$key = " + '$null'
            }
            else {

        # value is numeric
                if ($value -as [long] -or $value -eq '0') {
                    $line = "$($key) = $value"
                }
                else {

        # delimeter : was inside of quotes
                    $line = "$($key):$($value)"
                }
            }
        }
        else {

        # was no value on this line
            $line = $key
        }

        # replace end of line character ;
        if (! $finalEntry) {
            $line = "$line;"
        }

        $pscode += "$line`n"
    }

    $pscode = '$myObject = ' + $pscode

    $pscode | out-file $psFile
    return $pscode
}

# add a property
function setApiProperty{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)][string]$name,
        [Parameter(Mandatory = $True)][System.Object]$value,
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)][System.Object]$object
    )
    if(! $object.PSObject.Properties[$name]){
        $object | Add-Member -MemberType NoteProperty -Name $name -Value $value
    }else{
        $object.$name = $value
    }
}

# delete a propery
function delApiProperty{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)][string]$name,
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)][System.Object]$object
    )
    $object.PSObject.Members.Remove($name)
}


### authenticate
apiauth -vip $vip -username $username -domain $domain

### search for database to clone
$searchresults = api get /searchvms?environment=SQL`&entityTypes=kSQL`&entityTypes=kVMware`&vmName=$sourceDB

### handle source instance name e.g. instance/dbname
if($sourceDB.Contains('/')){
    $sourceDB = $sourceDB.Split('/')[1]
}

### narrow the search results to the correct source server
$dbresults = $searchresults.vms | Where-Object {$_.vmDocument.objectAliases -eq $sourceServer }
if($null -eq $dbresults){
    write-host "Server $sourceServer Not Found" -foregroundcolor yellow
    exit
}

### narrow the search results to the correct source database
$dbresults = $dbresults | Where-Object { $_.vmDocument.objectId.entity.sqlEntity.databaseName -eq $sourceDB }
if($null -eq $dbresults){
    write-host "Database $sourceDB Not Found" -foregroundcolor yellow
    exit
}

### if there are multiple results (e.g. old/new jobs?) select the one with the newest snapshot 
$latestdb = ($dbresults | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

if($null -eq $latestdb){
    write-host "Database Not Found" -foregroundcolor yellow
    exit 1
}

### identify physical or vm
$entityType = $latestdb.registeredSource.type

### search for source server
$entities = api get /appEntities?appEnvType=3`&envType=$entityType
$ownerId = $latestdb.vmDocument.objectId.entity.sqlEntity.ownerId

### handle log replay
$versionNum = 0
$validLogTime = $False

if ($logTime -or $latest) {
    if($logTime){
        $logUsecs = dateToUsecs $logTime
    }
    $dbVersions = $latestdb.vmDocument.versions

    foreach ($version in $dbVersions) {
        ### find db date before log time
        $GetRestoreAppTimeRangesArg = @{
            'type'                = 3;
            'restoreAppObjectVec' = @(
                @{
                    'appEntity'     = $latestdb.vmDocument.objectId.entity;
                    'restoreParams' = @{
                        'sqlRestoreParams'    = @{
                            'captureTailLogs'                 = $false;
                            'newDatabaseName'                 = $sourceDB;
                            'alternateLocationParams'         = @{};
                            'secondaryDataFileDestinationVec' = @(@{})
                        };
                        'oracleRestoreParams' = @{
                            'alternateLocationParams' = @{}
                        }
                    }
                }
            );
            'ownerObjectVec'      = @(
                @{
                    'jobUid'         = $latestdb.vmDocument.objectId.jobUid;
                    'jobId'          = $latestdb.vmDocument.objectId.jobId;
                    'jobInstanceId'  = $version.instanceId.jobInstanceId;
                    'startTimeUsecs' = $version.instanceId.jobStartTimeUsecs;
                    "entity" = @{
                        "id" = $ownerId
                    }
                    'attemptNum'     = 1
                }
            )
        }
        $logTimeRange = api post /restoreApp/timeRanges $GetRestoreAppTimeRangesArg
        if($latest){
            if(! $logTimeRange.ownerObjectTimeRangeInfoVec[0].PSobject.Properties['timeRangeVec']){
                $logTime = $null
                $latest = $null
                break
            }
        }
        $logStart = $logTimeRange.ownerObjectTimeRangeInfoVec[0].timeRangeVec[0].startTimeUsecs
        $logEnd = $logTimeRange.ownerObjectTimeRangeInfoVec[0].timeRangeVec[0].endTimeUsecs
        if($latest){
            $logUsecs = $logEnd - 1000000
            $validLogTime = $True
            break
        }
        if ($logStart -le $logUsecs -and $logUsecs -le $logEnd) {
            $validLogTime = $True
            break
        }
        $versionNum += 1
    }
}

### create new clone task (RestoreAppArg Object)
$restoreTask = @{
    "name" = "dbRestore-$(dateToUsecs (get-date))";
    'action' = 'kRecoverApp';
    'restoreAppParams' = @{
        'type' = 3;
        'ownerRestoreInfo' = @{
            "ownerObject" = @{
                "jobUid" = $latestdb.vmDocument.objectId.jobUid;
                "jobId" = $latestdb.vmDocument.objectId.jobId;
                "jobInstanceId" = $latestdb.vmDocument.versions[$versionNum].instanceId.jobInstanceId;
                "startTimeUsecs" = $latestdb.vmDocument.versions[$versionNum].instanceId.jobStartTimeUsecs;
                "entity" = @{
                    "id" = $ownerId
                }
            }
            'ownerRestoreParams' = @{
                'action' = 'kRecoverVMs';
                'powerStateConfig' = @{}
            };
            'performRestore' = $false
        };
        'restoreAppObjectVec' = @(
            @{
                "appEntity" = $latestdb.vmDocument.objectId.entity;
                'restoreParams' = @{
                    'sqlRestoreParams' = @{
                        'captureTailLogs' = $false;
                        'secondaryDataFileDestinationVec' = @();
                        'alternateLocationParams' = @{};
                    };
                }
            }
        )
    }
}

if($noRecovery){
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.withNoRecovery = $True
}

### if not restoring to original server/DB
if($targetDB -ne $sourceDB -or $targetServer -ne $sourceServer){
    if('' -eq $mdfFolder){
        write-host "-mdfFolder must be specified when restoring to a new database name or different target server" -ForegroundColor Yellow
        exit
    }
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['dataFileDestination'] = $mdfFolder;
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['logFileDestination'] = $ldfFolder;
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['secondaryDataFileDestinationVec'] = $secondaryFileLocation;
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['newDatabaseName'] = $targetDB;    
}

### overwrite warning
if($targetDB -eq $sourceDB -and $targetServer -eq $sourceServer){
    if(! $overWrite){
        write-host "Please use the -overWrite parameter to confirm overwrite of the source database!" -ForegroundColor Yellow
        exit
    }
}

### apply log replay time
if($validLogTime -eq $True){
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['restoreTimeSecs'] = $([int64]($logUsecs/1000000))
}else{
    if($logTime){
        Write-Host "LogTime of $logTime is out of range" -ForegroundColor Yellow
        Write-Host "Available range is $(usecsToDate $logStart) to $(usecsToDate $logEnd)" -ForegroundColor Yellow
        exit 1
    }
}

### search for target server
if($targetServer -ne $sourceServer){
    $targetEntity = $entities | where-object { $_.appEntity.entity.displayName -eq $targetServer }
    if($null -eq $targetEntity){
        Write-Host "Target Server Not Found" -ForegroundColor Yellow
        exit 1
    }
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams['targetHost'] = $targetEntity.appEntity.entity;
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams['targetHostParentSource'] = @{ 'id' = $targetEntity.appEntity.entity.parentId }
    if($targetInstance){
        $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['instanceName'] = $targetInstance
    }else{
        $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['instanceName'] = 'MSSQLSERVER'
    }
}else{
    $targetServer = $sourceServer
}

### handle 5.0x secondary file location
if($ndfFolder){
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['secondaryDataFileDestination'] = $ndfFolder
}

### overWrite existing DB
if($overWrite){
    $restoreTask.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams['dbRestoreOverwritePolicy'] = 1
}

#$restoreTask | ConvertTo-Json -Depth 99
#exit

### execute the recovery task (post /recoverApplication api call)
$response = api post /recoverApplication $restoreTask

if($response){
    "Restoring $sourceDB to $targetServer as $targetDB"
}

if($wait -or $progress){
    $lastProgress = -1
    $taskId = $response.restoreTask.performRestoreTaskState.base.taskId
    $finishedStates = @('kSuccess','kFailed','kCanceled', 'kFailure')
    while($True){
        $status = (api get /restoretasks/$taskId).restoreTask.performRestoreTaskState.base.publicStatus
        if($progress){
            $progressMonitor = api get "/progressMonitors?taskPathVec=restore_sql_$($taskId)&includeFinishedTasks=true&excludeSubTasks=false"
            $percentComplete = $progressMonitor.resultGroupVec[0].taskVec[0].progress.percentFinished
            if($percentComplete -gt $lastProgress){
                "{0} percent complete" -f [math]::Round($percentComplete, 0)
                $lastProgress = $percentComplete
            }
        }
        if ($status -in $finishedStates){
            break
        }
        sleep 5
    }
    "restore ended with $status"
    if($status -eq 'kSuccess'){
        exit 0
    }else{
        exit 1
    }
}

exit 0
