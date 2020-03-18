# . . . . . . . . . . . . . . . . . . . . . . . .
#  Unofficial PowerShell Module for Cohesity API
#   version 0.20 - Brian Seltzer - Mar 2020
# . . . . . . . . . . . . . . . . . . . . . . . .
#
# 0.06 - Consolidated Windows and Unix versions - June 2018
# 0.07 - Added saveJson, loadJson and json2code utility functions - Feb 2019
# 0.08 - added -prompt to prompt for password rather than save - Mar 2019
# 0.09 - added setApiProperty / delApiProperty - Apr 2019
# 0.10 - added $REPORTAPIERRORS constant - Apr 2019
# 0.11 - added storePassword function and username parsing - Aug 2019
# 0.12 - added -password to apiauth function - Oct 2019
# 0.13 - added showProps function - Nov 2019
# 0.14 - added storePasswordFromInput function - Dec 2019
# 0.15 - added support for PS Core on Windows - Dec 2019
# 0.16 - added ServicePoint connection workaround - Jan 2020
# 0.17 - fixed json2code line endings on Windows - Jan 2020
# 0.18 - added REINVOKE - Jan 2020
# 0.19 - fixed password encryption for PowerShell 7.0 - Mar 2020
# 0.20 - refactored, added apipwd, added helios access - Mar 2020
#
# . . . . . . . . . . . . . . . . . . . . . . . . 

$REPORTAPIERRORS = $true
$REINVOKE = 0
$MAXREINVOKE = 2

# platform detection and prerequisites ============================================================

if ($PSVersionTable.Platform -eq 'Unix') {
    $CONFDIR = '~/.cohesity-api'
    if ($(Test-Path $CONFDIR) -eq $false) { $null = New-Item -Type Directory -Path $CONFDIR}
}else{
    $registryPath = 'HKCU:\Software\Cohesity-API'
    $WEBCLI = New-Object System.Net.WebClient;    
}

if($PSVersionTable.PSEdition -eq 'Desktop'){
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true }
    $ignoreCerts = @"
public class SSLHandler
{
    public static System.Net.Security.RemoteCertificateValidationCallback GetSSLHandler()
    {
        return new System.Net.Security.RemoteCertificateValidationCallback((sender, certificate, chain, policyErrors) => { return true; });
    }
}
"@

    Add-Type -TypeDefinition $ignoreCerts
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [SSLHandler]::GetSSLHandler()
}

# authentication functions ========================================================================

function apiauth($vip, $username='helios', $domain='local', $pwd=$null, $password = $null, [switch] $quiet, [switch] $noprompt, [switch] $updatePassword, [switch] $helios){
    # prompt for vip
    if(-not $vip){
        if($helios){
            $vip = 'helios.cohesity.com'
        }else{
            write-host 'VIP: ' -foregroundcolor green -nonewline
            $vip = Read-Host
            if(-not $vip){write-host 'vip is required' -foregroundcolor red; break}
        }
    }
    # prompt for username
    if($username -eq 'helios' -and !$helios -and $vip -ne 'helios.cohesity.com'){
        write-host 'Username: ' -foregroundcolor green -nonewline
        $username = Read-Host
    }
    # parse domain\username or username@domain
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    if($username.Contains('@')){
        $username, $domain = $username.Split('@')
    }
    if($password){ $pwd = $password }
    if($updatePassword){
        Set-CohesityAPIPassword -vip $vip -username $username -domain $domain
    }
    # get password
    if(!$pwd){
        $pwd = Get-CohesityAPIPassword -vip $vip -username $username -domain $domain
        if(!$pwd -and !$noprompt){
            Set-CohesityAPIPassword -vip $vip -username $username -domain $domain
            $pwd = Get-CohesityAPIPassword -vip $vip -username $username -domain $domain
        }
        if(!$pwd){
            Write-Host "No password provided for $username at $vip" -ForegroundColor Yellow
            $global:AUTHORIZED = $false
            break
        }
    }

    $body = ConvertTo-Json @{
        'domain' = $domain;
        'username' = $username;
        'password' = $pwd
    }

    $global:VIP = $vip
    $global:USERNAME = $username
    $global:DOMAIN = $domain
    $global:SELECTEDCLUSTER = $null
    $global:APIROOT = 'https://' + $vip + '/irisservices/api/v1'
    $HEADER = @{'accept' = 'application/json'; 'content-type' = 'application/json'}
    if($vip -eq 'helios.cohesity.com' -or $helios){
        # Authenticate Helios
        $HEADER['apiKey'] = $pwd
        $URL = 'https://helios.cohesity.com/mcm/clusters/connectionStatus'
        try{
            if($PSVersionTable.Edition -eq 'Core'){
                $global:HELIOSALLCLUSTERS = Invoke-RestMethod -Method get -Uri $URL -Header $HEADER -SkipCertificateCheck
            }else{
                $global:HELIOSALLCLUSTERS = Invoke-RestMethod -Method get -Uri $URL -Header $HEADER
            }
            $global:HELIOSCONNECTEDCLUSTERS = $global:HELIOSALLCLUSTERS | Where-Object connectedToCluster -eq $true
            $global:HEADER = $HEADER
            $global:AUTHORIZED = $true
            $global:CLUSTERSELECTED = $false
            $global:USING_HELIOS = $true
            if(!$quiet){ write-host "Connected!" -foregroundcolor green }
        }catch{
            if($_.ToString().contains('"message":')){
                write-host (ConvertFrom-Json $_.ToString()).message -foregroundcolor yellow
            }else{
                write-host $_.ToString() -foregroundcolor yellow
            }
        }
    }else{
        # Authenticate Cluster
        $url = $APIROOT + '/public/accessTokens'
        try {
            # authenticate
            if($PSVersionTable.PSEdition -eq 'Core'){
                $auth = Invoke-RestMethod -Method Post -Uri $url -Header $HEADER -Body $body -SkipCertificateCheck
            }else{
                $auth = Invoke-RestMethod -Method Post -Uri $url -Header $HEADER -Body $body
            }
            # set file transfer details
            if($PSVersionTable.Platform -eq 'Unix'){
                $global:CURLHEADER = "authorization: $($auth.tokenType) $($auth.accessToken)"
            }else{
                $WEBCLI.Headers['authorization'] = $auth.tokenType + ' ' + $auth.accessToken;
            }
            # store token
            $global:AUTHORIZED = $true
            $global:CLUSTERSELECTED = $true
            $global:USING_HELIOS = $false
            $global:HEADER = @{'accept' = 'application/json'; 
                'content-type' = 'application/json'; 
                'authorization' = $auth.tokenType + ' ' + $auth.accessToken
            }
            if(!$quiet){ write-host "Connected!" -foregroundcolor green }
        }catch{
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
}

# select helios access cluster
function heliosCluster($clusterName, [switch] $quiet){
    if($clusterName){
        $cluster = $HELIOSCONNECTEDCLUSTERS | Where-Object name -eq $clusterName
        if($cluster){
            $global:HEADER.accessClusterId = $cluster.clusterId
            $global:CLUSTERSELECTED = $true
            $global:SELECTEDCLUSTER = $cluster.name
            $global:CLUSTERREADONLY = (api get /mcm/config).mcmReadOnly
            if(!$quiet){
                return "Using $($cluster.name)"
            }
        }else{
            Write-Host "Cluster $clusterName not connected to Helios" -ForegroundColor Yellow
            $global:CLUSTERSELECTED = $false
            return $null
        }
    }else{
        $HELIOSCONNECTEDCLUSTERS | Sort-Object -Property name | Select-Object -Property name, clusterId, softwareVersion
    }
}

function heliosClusters(){
    heliosCluster
}

# api password setter/updater tool
function apipwd($vip, $username='helios', $domain='local', [switch] $asUser, [switch] $helios){
    # prompt for vip
    if(-not $vip){
        if($helios){
            $vip = 'helios.cohesity.com'
        }else{
            write-host 'VIP: ' -foregroundcolor green -nonewline
            $vip = Read-Host
            if(-not $vip){write-host 'vip is required' -foregroundcolor red; break}
        }
    }
    # prompt for username
    if($username -eq 'helios' -and !$helios -and $vip -ne 'helios.cohesity.com'){
        write-host 'Username: ' -foregroundcolor green -nonewline
        $username = Read-Host
    }
    # parse domain\username or username@domain
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    if($username.Contains('@')){
        $username, $domain = $username.Split('@')
    }
    if($password){ $pwd = $password }
    if($helios){
        if(!$asUser){
            apiauth -username $username -helios -updatePassword
        }else{
            if($PSVersionTable.Platform -ne 'Unix'){
                $credential = Get-Credential -Message "Enter Credentials for the Windows User"
    
                $args = "write-host ('running as ' + [System.Security.Principal.WindowsIdentity]::GetCurrent().Name);
                . $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1);
                apiauth {0} -helios -updatePassword;
                pause;" -f $username

                Start-Process powershell.exe -Credential $credential -ArgumentList ("-command $args")
            }else{
                Write-Host "The -asUser option is only valid for Windows" -ForegroundColor Yellow
            }
        }
    }else{
        if(!$asUser){
            apiauth $vip $username $domain -updatePassword
        }else{
            if($PSVersionTable.Platform -ne 'Unix'){
                $credential = Get-Credential -Message "Enter Credentials for the Windows User"
    
                $args = "write-host ('running as ' + [System.Security.Principal.WindowsIdentity]::GetCurrent().Name);
                . $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1);
                apiauth -vip {0} -username {1} -domain {2} -updatePassword;
                pause;" -f $vip, $username, $domain
        
                Start-Process powershell.exe -Credential $credential -ArgumentList ("-command $args")
            }else{
                Write-Host "The -asUser option is only valid for Windows" -ForegroundColor Yellow
            }
        }
    }
}

# terminate authentication
function apidrop([switch] $quiet){
    $global:AUTHORIZED = $false
    $global:HEADER = ''
    if(!$quiet){ write-host "Disonnected!" -foregroundcolor green }
}

# api call functions ==============================================================================

$methods = 'get', 'post', 'put', 'delete'
function api($method, $uri, $data){
    if (-not $global:AUTHORIZED){ 
        if($REPORTAPIERRORS){
            write-host 'Please use apiauth to connect to a cohesity cluster' -foregroundcolor yellow
        }
    }elseif(-not $global:CLUSTERSELECTED){
        if($REPORTAPIERRORS){
            write-host 'Please use heliosCluster to connect to a cohesity cluster' -ForegroundColor Yellow
        }
    }else{
        if($method -ne 'get' -and $global:CLUSTERREADONLY -eq $true){
            write-host "Cluster connection is READ-ONLY" -ForegroundColor Yellow
            break
        }
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
            if ($PSVersionTable.PSEdition -eq 'Core'){
                if($method -eq 'post' -or $method -eq 'put'){
                    $result = Invoke-RestMethod -Method $method -Uri $url -Body $body -Header $HEADER -SkipCertificateCheck -TimeoutSec 10
                }else{
                    $result = Invoke-RestMethod -Method $method -Uri $url -Header $HEADER -SkipCertificateCheck -TimeoutSec 10
                }
            }else{
                $result = Invoke-RestMethod -Method $method -Uri $url -Body $body -Header $HEADER -TimeoutSec 10
            }
            $global:REINVOKE = 0
            return $result
        }
        catch {
            if($REPORTAPIERRORS -and $global:REINVOKE -ge $MAXREINVOKE){
                if($_.ToString().contains('"message":')){
                    write-host (ConvertFrom-Json $_.ToString()).message -foregroundcolor yellow
                }else{
                    write-host $_.ToString() -foregroundcolor yellow
                }
            }
            if($global:REINVOKE -lt $MAXREINVOKE){
                $global:REINVOKE += 1
                $hcluster = $global:SELECTEDCLUSTER
                apiauth -vip $global:VIP -username $global:USERNAME -domain $global:DOMAIN -quiet
                if($hcluster){ heliosCluster $hcluster -quiet}
                api $method $uri $data
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

# date functions ==================================================================================

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

# password functions ==============================================================================

function Get-CohesityAPIPassword($vip, $username, $domain='local'){
    $keyName = "$vip`:$domain`:$username"
    if($PSVersionTable.Platform -eq 'Unix'){
        # Unix
        $keyFile = "$CONFDIR/$keyName"
        if (Test-Path $keyFile) {
            $key, $storedPassword = Get-Content $keyFile
            return Unprotect-CohesityAPIPassword $key $storedPassword
        }
    }else{
        # Windows
        $storedPassword = Get-ItemProperty -Path "$registryPath" -Name "$keyName" -ErrorAction SilentlyContinue
        If (($null -ne $storedPassword) -and ($storedPassword.Length -ne 0)) {
            $securePassword = $storedPassword.$keyName  | ConvertTo-SecureString
            return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $securePassword ))
        }
    }
}

function Set-CohesityAPIPassword($vip, $username, $domain='local', $pwd=$null){
    # prompt for vip
    if(-not $vip){
        write-host 'VIP: ' -foregroundcolor green -nonewline
        $vip = Read-Host
        if(-not $vip){write-host 'vip is required' -foregroundcolor red; break}
    }
    # prompt for username
    if(-not $username){
        write-host 'Username: ' -foregroundcolor green -nonewline
        $username = Read-Host
        if(-not $username){write-host 'username is required' -foregroundcolor red; break}
    }
    # parse domain\username or username@domain
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    if($username.Contains('@')){
        $username, $domain = $username.Split('@')
    }
    $keyName = "$vip`:$domain`:$username"
    if(!$pwd){
        $secureString = Read-Host -Prompt "Enter password for $username at $vip" -AsSecureString
        $pwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
    }
    if($PSVersionTable.Platform -eq 'Unix'){
        # Unix
        $keyFile = "$CONFDIR/$keyName"
        $key = New-AesKey 
        $key | Out-File $keyFile
        Protect-CohesityAPIPassword $key $pwd | Out-File $keyFile -Append
    }else{
        # Windows
        $securePassword = ConvertTo-SecureString -String $pwd -AsPlainText -Force
        $encryptedPasswordText = $securePassword | ConvertFrom-SecureString
        if(!(Test-Path $registryPath)){
            New-Item -Path $registryPath -Force | Out-Null
        }
        Set-ItemProperty -Path "$registryPath" -Name "$keyName" -Value "$encryptedPasswordText"
    }
}

# security functions ==============================================================================

function New-AesManagedObject($key, $IV){
    $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
    $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $aesManaged.BlockSize = 128
    $aesManaged.KeySize = 256
    if($IV){
        if($IV.getType().Name -eq "String"){
            $aesManaged.IV = [System.Convert]::FromBase64String($IV)
        }else{
            $aesManaged.IV = $IV
        }
    }
    if($key){
        if($key.getType().Name -eq "String") {
            $aesManaged.Key = [System.Convert]::FromBase64String($key)
        }else{
            $aesManaged.Key = $key
        }
    }
    $aesManaged
}

function New-AesKey() {
    $aesManaged = New-AesManagedObject
    $aesManaged.GenerateKey()
    [System.Convert]::ToBase64String($aesManaged.Key)
}

function Protect-CohesityAPIPassword($key, $unencryptedString) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($unencryptedString)
    $aesManaged = New-AesManagedObject $key
    $encryptor = $aesManaged.CreateEncryptor()
    $encryptedData = $encryptor.TransformFinalBlock($bytes, 0, $bytes.Length);
    [byte[]] $fullData = $aesManaged.IV + $encryptedData
    $aesManaged.Dispose()
    [System.Convert]::ToBase64String($fullData)
}

function Unprotect-CohesityAPIPassword($key, $encryptedStringWithIV) {
    $bytes = [System.Convert]::FromBase64String($encryptedStringWithIV)
    $IV = $bytes[0..15]
    $aesManaged = New-AesManagedObject $key $IV
    $decryptor = $aesManaged.CreateDecryptor();
    $unencryptedData = $decryptor.TransformFinalBlock($bytes, 16, $bytes.Length - 16);
    $aesManaged.Dispose()
    [System.Text.Encoding]::UTF8.GetString($unencryptedData).Trim([char]0)
}

# developer tools =================================================================================

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
        $line = $line.TrimEnd()
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

# show properties of an object
function showProps{
    param (
        [Parameter(Mandatory = $True)]$obj,
        [Parameter()]$parent = 'myobject',
        [Parameter()]$search = $null
    )
    if($obj.getType().Name -eq 'String' -or $obj.getType().Name -eq 'Int64'){
        if($null -ne $search){
            if($parent.ToLower().Contains($search) -or ($obj.getType().Name -eq 'String' -and $obj.ToLower().Contains($search))){
                "$parent = $obj"
            }
        }else{
            "$parent = $obj"
        }
        
    }else{ 
        foreach($prop in $obj.PSObject.Properties | Sort-Object -Property Name){
            if($($prop.Value.GetType().Name) -eq 'PSCustomObject'){
                $thisObj = $prop.Value
                showProps $thisObj "$parent.$($prop.Name)" $search
            }elseif($($prop.Value.GetType().Name) -eq 'Object[]'){
                $thisObj = $prop.Value
                $x = 0
                foreach($item in $thisObj){
                    showProps $thisObj[$x] "$parent.$($prop.Name)[$x]" $search
                    $x += 1
                }
            }else{
                if($null -ne $search){
                    if($prop.Name.ToLower().Contains($search.ToLower()) -or ($prop.Value.getType().Name -eq 'String' -and $prop.Value.ToLower().Contains($search.ToLower()))){
                        "$parent.$($prop.Name) = $($prop.Value)"
                    }
                }else{
                    "$parent.$($prop.Name) = $($prop.Value)"
                }
            }
        }
    }
}

# convert syntax to python
function py($p){
    $py = $p.replace("$","").replace("].","]['").replace(".","']['")
    if($py[-1] -ne ']'){
        $py += "']"
    }
    $py
}
