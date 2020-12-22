# . . . . . . . . . . . . . . . . . . .
#  PowerShell Module for Cohesity API
#  Version 2020.12.22 - Brian Seltzer
# . . . . . . . . . . . . . . . . . . .
#
# 2020.10.16 - added password parameter to storePasswordInFile function
# 2020.10.20 - code cleanup (moved old version history to end of file)
# 2020.12.22 - added v2 support for file download
#
# . . . . . . . . . . . . . . . . . . . . . . . . 
$versionCohesityAPI = '2020.12.22'

# demand modern powershell version (must support TLSv1.2)
if($Host.Version.Major -le 5 -and $Host.Version.Minor -lt 1){
    Write-Warning "PowerShell version must be upgraded to 5.1 or higher to connect to Cohesity!"
    Pause
    exit
}

$REPORTAPIERRORS = $true

$pwfile = $(Join-Path -Path $PSScriptRoot -ChildPath YWRtaW4)
$apilogfile = $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api-debug.log)

# platform detection ==========================================================================
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

    if(!("SSLHandler" -as [type])){
        Add-Type -TypeDefinition $ignoreCerts
    }
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [SSLHandler]::GetSSLHandler()
}

function __writeLog($logmessage){
    "$(Get-Date): $logmessage" | Out-File -FilePath $apilogfile -Append
}

# authentication functions ========================================================================

function apiauth($vip, $username='helios', $domain='local', $passwd=$null, $password = $null, $tenantId = $null, [switch] $quiet, [switch] $noprompt, [switch] $updatePassword, [switch] $helios, [switch] $useApiKey){

    if(-not $vip){
        if($helios){
            $vip = 'helios.cohesity.com'
        }else{
            Write-Host 'vip is required' -foregroundcolor Yellow
            break
        }
    }

    # parse domain\username or username@domain
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    if($password){ $passwd = $password }
    if($updatePassword){
        $fpasswd = Get-CohesityAPIPasswordFromFile -vip $vip -username $username -domain $domain
        if($fpasswd){
            storePasswordInFile  -vip $vip -username $username -domain $domain
        }else{
            Set-CohesityAPIPassword -vip $vip -username $username -domain $domain
        }
    }
    # get password
    if(!$passwd){
        $passwd = Get-CohesityAPIPassword -vip $vip -username $username -domain $domain
        if(!$passwd -and !$noprompt){
            Set-CohesityAPIPassword -vip $vip -username $username -domain $domain
            $passwd = Get-CohesityAPIPassword -vip $vip -username $username -domain $domain
        }
        if(!$passwd){
            Write-Host "No password provided for $username at $vip" -ForegroundColor Yellow
            $global:AUTHORIZED = $false
            break
        }
    }

    $body = ConvertTo-Json @{
        'domain' = $domain;
        'username' = $username;
        'password' = $passwd
    }

    $global:APIROOT = 'https://' + $vip + '/irisservices/api/v1'
    $global:APIROOTv2 = 'https://' + $vip + '/v2/'
    $HEADER = @{'accept' = 'application/json'; 'content-type' = 'application/json'}
    if($useApiKey){
        $HEADER['apiKey'] = $passwd
        $global:HEADER = $HEADER
        $global:AUTHORIZED = $true
        $global:CLUSTERSELECTED = $true
        $cluster = api get cluster
        if($cluster){
            if(!$quiet){ Write-Host "Connected!" -foregroundcolor green }
        }else{
            $global:AUTHORIZED = $false
        }
    }elseif($vip -eq 'helios.cohesity.com' -or $helios){
        # Authenticate Helios
        $HEADER['apiKey'] = $passwd
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
            $global:CLUSTERREADONLY = $false
            if(!$quiet){ Write-Host "Connected!" -foregroundcolor green }
        }catch{
            $global:AUTHORIZED = $false
            __writeLog $_.ToString()
            if($_.ToString().contains('"message":')){
                Write-Host (ConvertFrom-Json $_.ToString()).message -foregroundcolor yellow
            }else{
                Write-Host $_.ToString() -foregroundcolor yellow
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
            $global:CLUSTERREADONLY = $false
            $global:HEADER = @{'accept' = 'application/json'; 
                'content-type' = 'application/json'; 
                'authorization' = $auth.tokenType + ' ' + $auth.accessToken
            }
            if($tenantId){
                $global:HEADER['x-impersonate-tenant-id'] = "$tenantId/"
            }
            if(!$quiet){ Write-Host "Connected!" -foregroundcolor green }
        }catch{
            $global:AUTHORIZED = $false
            __writeLog $_.ToString()
            $global:AUTHORIZED = $false
            if($REPORTAPIERRORS){
                if($_.ToString().contains('"message":')){
                    Write-Host (ConvertFrom-Json $_.ToString()).message -foregroundcolor yellow
                }else{
                    Write-Host $_.ToString() -foregroundcolor yellow
                }
            }
        }
    }
}

# select helios access cluster
function heliosCluster($clusterName, [switch] $verbose){
    if($clusterName -and $HELIOSCONNECTEDCLUSTERS){
        if(! ($clusterName -is [string])){
            $clusterName = $clusterName.name
        }
        $cluster = $HELIOSCONNECTEDCLUSTERS | Where-Object name -eq $clusterName
        if($cluster){
            $global:HEADER.accessClusterId = $cluster.clusterId
            $global:CLUSTERSELECTED = $true
            $global:CLUSTERREADONLY = (api get /mcm/config).mcmReadOnly
            if($verbose){
                Write-Host "Connected ($($cluster.name))" -ForegroundColor Green
            }
        }else{
            Write-Host "Cluster $clusterName not connected to Helios" -ForegroundColor Yellow
            $global:CLUSTERSELECTED = $false
            return $null
        }
    }else{
        $HELIOSCONNECTEDCLUSTERS | Sort-Object -Property name | Select-Object -Property name, clusterId, softwareVersion
        "`ntype heliosCluster <clustername> to connect to a cluster"
    }
    if (-not $global:AUTHORIZED){ 
        if($REPORTAPIERRORS){
            Write-Host 'Please use apiauth to connect to helios' -foregroundcolor yellow
        }
    }
}

function heliosClusters(){
    return $HELIOSCONNECTEDCLUSTERS | Sort-Object -Property name
}

# terminate authentication
function apidrop([switch] $quiet){
    $global:AUTHORIZED = $false
    $global:HEADER = ''
    $global:HELIOSALLCLUSTERS = $null
    $global:HELIOSCONNECTEDCLUSTERS = $null
    if(!$quiet){ Write-Host "Disonnected!" -foregroundcolor green }
}

# api call functions ==============================================================================

$methods = 'get', 'post', 'put', 'delete'
function api($method, $uri, $data, $version=1, [switch]$v2){
    if (-not $global:AUTHORIZED){ 
        if($REPORTAPIERRORS){
            Write-Host 'Not authenticated to a cohesity cluster' -foregroundcolor yellow
            if($MyInvocation.PSCommandPath){
                exit 1
            }
        }
    }else{
        if($method -ne 'get' -and $global:CLUSTERREADONLY -eq $true){
            Write-Host "Cluster connection is READ-ONLY" -ForegroundColor Yellow
            break
        }
        if (-not $methods.Contains($method)){
            if($REPORTAPIERRORS){
                Write-Host "invalid api method: $method" -foregroundcolor yellow
            }
            break
        }
        try {
            
            if($version -eq 2 -or $v2){
                $url = $APIROOTv2 + $uri
            }else{
                if ($uri[0] -ne '/'){ $uri = '/public/' + $uri}
                $url = $APIROOT + $uri
            }
            $body = ConvertTo-Json -Depth 100 $data
            if ($PSVersionTable.PSEdition -eq 'Core'){
                if($body){
                    $result = Invoke-RestMethod -Method $method -Uri $url -Body $body -Header $HEADER -SkipCertificateCheck
                }else{
                    $result = Invoke-RestMethod -Method $method -Uri $url -Header $HEADER -SkipCertificateCheck
                }
            }else{
                $result = Invoke-RestMethod -Method $method -Uri $url -Body $body -Header $HEADER
            }
            return $result
        }catch{
            __writeLog $_.ToString()
            if($REPORTAPIERRORS){
                if($_.ToString().contains('"message":')){
                    Write-Host (ConvertFrom-Json $_.ToString()).message -foregroundcolor yellow
                }else{
                    Write-Host $_.ToString() -foregroundcolor yellow
                }
            }            
        }
    }
}

# file download function
function fileDownload($uri, $fileName, $version=1, [switch]$v2){
    if (-not $global:AUTHORIZED){ Write-Host 'Please use apiauth to connect to a cohesity cluster' -foregroundcolor yellow; break }
    try {
        if($version -eq 2 -or $v2){
            $url = $APIROOTv2 + $uri
        }else{
            if ($uri[0] -ne '/'){ $uri = '/public/' + $uri}
            $url = $APIROOT + $uri
        }
        if ($PSVersionTable.Platform -eq 'Unix'){
            curl -k -s -H "$global:CURLHEADER" -o "$fileName" "$url"
        }else{
            if($fileName -notmatch '\\'){
                $fileName = $(Join-Path -Path $PSScriptRoot -ChildPath $fileName)
            }
            $WEBCLI.DownloadFile($url, $fileName)
        } 
    }catch{
        __writeLog $_.ToString()
        $_.ToString()
        if($_.ToString().contains('"message":')){
            Write-Host (ConvertFrom-Json $_.ToString()).message -foregroundcolor yellow
        }else{
            Write-Host $_.ToString() -foregroundcolor yellow
        }                
    }
}

# date functions ==================================================================================

function timeAgo([int64] $age, [string] $units){
    $currentTime = [int64](((get-date).ToUniversalTime())-([datetime]"1970-01-01 00:00:00")).TotalSeconds*1000000
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
    $origin = ([datetime]'1970-01-01 00:00:00')
    return $origin.AddSeconds($unixTime).ToLocalTime()
}

function dateToUsecs($datestring){
    if($datestring -isnot [datetime]){ $datestring = [datetime] $datestring }
    $usecs = [int64](($datestring.ToUniversalTime())-([datetime]"1970-01-01 00:00:00")).TotalSeconds*1000000
    $usecs
}

# password functions ==============================================================================

function Get-CohesityAPIPassword($vip, $username, $domain='local'){
    # parse domain\username or username@domain
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    if($username.Contains('@')){
        $username, $domain = $username.Split('@')
    }
    $passwd = Get-CohesityAPIPasswordFromFile -vip $vip -username $username -domain $domain
    if($passwd){
        return $passwd
    }
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


function Get-CohesityAPIPasswordFromFile($vip, $username, $domain){
    $pwlist = Get-Content -Path $pwfile -ErrorAction SilentlyContinue
    foreach($pwitem in $pwlist){
        $v, $d, $u, $cpwd = $pwitem.split(":", 4)
        if($v -eq $vip -and $d -eq $domain -and $u -eq $username){
            return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cpwd))
        }
    }
    return $null
}


function storePasswordInFile($vip='helios.cohesity.com', $username='helios', $domain='local', [switch]$helios, $password=$null){
    # parse domain\username or username@domain
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    if($username.Contains('@')){
        $username, $domain = $username.Split('@')
    }

    if($vip -eq 'helios.cohesity.com' -and $username -eq 'helios' -and ! $helios){
        # prompt for vip
        __writeLog "Prompting for VIP, USERNAME, DOMAIN"
        $newVip = Read-Host -Prompt "Enter VIP ($vip)"
        if($newVip -ne ''){ $vip = $newVip }

        # prompt for domain
        $newDomain = Read-Host -Prompt "Enter domain ($domain)"
        if($newDomain -ne ''){ $domain = $newDomain }

        # prompt for username
        $newUsername = Read-Host -Prompt "Enter username ($username)"
        if($newUsername -ne ''){ $username = $newUsername }
    }

    # prompt for password
    __writeLog "Prompting for Password"
    if(!$password){
        $secureString = Read-Host -Prompt "Enter password for $domain\$username at $vip" -AsSecureString
        $passwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))    
    }else{
        $passwd = $password
    }
    $opwd = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($passwd))

    $pwlist = Get-Content -Path $pwfile -ErrorAction SilentlyContinue
    $updatedContent = ''
    $foundPwd = $false
    foreach($pwitem in $pwlist){
        $v, $d, $u, $cpwd = $pwitem.split(":", 4)
        # update existing
        if($v -eq $vip -and $d -eq $domain -and $u -eq $username){
            $foundPwd = $true
            $updatedContent += "{0}:{1}:{2}:{3}`n" -f $vip, $domain, $username, $opwd
        # other existing records    
        }else{
            if($pwitem -ne ''){
                $updatedContent += "{0}`n" -f $pwitem
            }
        }
    }
    # add new
    if(!$foundPwd){
        $updatedContent += "{0}:{1}:{2}:{3}`n" -f $vip, $domain, $username, $opwd
    }

    $updatedContent | out-file -FilePath $pwfile
    Write-Host "Password stored!" -ForegroundColor Green
}


function Set-CohesityAPIPassword($vip, $username, $domain='local', $passwd=$null){
    # prompt for vip
    if(-not $vip){
        __writeLog "Prompting for VIP"
        Write-Host 'VIP: ' -foregroundcolor green -nonewline
        $vip = Read-Host
        if(-not $vip){Write-Host 'vip is required' -foregroundcolor red; break}
    }
    # prompt for username
    if(-not $username){
        __writeLog "Prompting for Username"
        Write-Host 'Username: ' -foregroundcolor green -nonewline
        $username = Read-Host
        if(-not $username){Write-Host 'username is required' -foregroundcolor red; break}
    }
    # parse domain\username or username@domain
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    if($username.Contains('@')){
        $username, $domain = $username.Split('@')
    }
    $keyName = "$vip`:$domain`:$username"
    if(!$passwd){
        __writeLog "Prompting for Password"
        $secureString = Read-Host -Prompt "Enter password for $username at $vip" -AsSecureString
        $passwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
    }
    if($PSVersionTable.Platform -eq 'Unix'){
        # Unix
        $keyFile = "$CONFDIR/$keyName"
        $key = New-AesKey 
        $key | Out-File $keyFile
        Protect-CohesityAPIPassword $key $passwd | Out-File $keyFile -Append
    }else{
        # Windows
        $securePassword = ConvertTo-SecureString -String $passwd -AsPlainText -Force
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


# self updater
function cohesityAPIversion([switch]$update){
    if($update){
        $repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
        (Invoke-WebRequest -Uri "$repoURL/cohesity-api/cohesity-api.ps1").content | Out-File -Force cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
        Write-Host "Cohesity-API version updated! Please restart PowerShell"
    }else{
        Write-Host "Cohesity-API version $versionCohesityAPI" -ForegroundColor Green 
    }
}


# paged view list
function getViews([switch]$includeInactive){
    $myViews = @()
    $views = $null
    while(! $views){
        if($includeInactive){
            $views = api get views?includeInactive=true
        }else{
            $views = api get views
        }
    }
    $myViews += $views.views
    $lastResult = $views.lastResult
    while(! $lastResult){
        $lastViewId = $views.views[-1].viewId
        $views = $null
        while(! $views){
            if($includeInactive){
                $views = api get "views?maxViewId=$lastViewId&includeInactive=true"
            }else{
                $views = api get views?maxViewId=$lastViewId
            }
        }
        $lastResult = $views.lastResult
        $myViews += $views.views
    }
    return $myViews
}

# old version history
# . . . . . . . . . . . . . . . . . . . . . . . . 
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
# 0.21 - helios changes - Mar 2020
# 0.22 - added password file storage - Apr 2020
# 0.23 - added self updater - Apr 2020
# 0.24 - added delete with body - Apr 2020
# 0.25 - added paged view list - Apr 2020
# 0.26 - added support for tenants - May 2020
# 0.27 - added support for Iris API Key - May 2020
# 0.28 - added reprompt for password, debug log - June 2020
# 0.29 - update storePasswordInFile - June 2020
# 2020.06.04 - updated version numbering - June 2020
# 2020.06.16 - improved REINVOKE - June 2020
# 2020-06.25 - added API v2 support (-version 2) or (-v2)
# 2020.07.08 - removed timout
# 2020.07.20 - fixed dateToUsecs for international date formats
# 2020.07.30 - quiet ssl handler
# 2020.08.08 - fixed timezone issue
# 2020.10.02 - set PROMPTFORPASSWORDCHANGE to false
# 2020.10.05 - retired REINVOKE
# 2020.10.06 - exit script when attempting unauthenticated api call
# 2020.10.13 - fixed timeAgo function for i14n
# . . . . . . . . . . . . . . . . . . . . . . . . 
