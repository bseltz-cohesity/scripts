# platform detection and prerequisites

if ($PSVersionTable.Platform -eq 'Unix') {
    $global:UNIX = $true
    $global:CONFDIR = '~/.cohesity-api'
    if ($(Test-Path $global:CONFDIR) -eq $false) { $quiet = New-Item -Type Directory -Path $global:CONFDIR}
}
else {
    $global:UNIX = $false

    #ignore unsigned certificates
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
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


class CohesityCluster {
    [string]$APIROOT
    [hashtable]$HEADER
    [bool]$AUTHORIZED
    [string]$CURLHEADER
    [System.Object]$WEBCLI
    [string]$SERVER
    [string]$USERNAME
    [string]$DOMAIN
    [string]$PASSWORD

    CohesityCluster([string]$server, [string]$username, [string]$domain, [string]$password, [switch]$updatePassword=$false, [switch] $quiet=$false){

        $this.SERVER = $server
        $this.USERNAME = $username
        $this.DOMAIN = $domain
        $this.PASSWORD = $password

        if($global:UNIX -eq $false){
            $this.WEBCLI = New-Object System.Net.WebClient;
        }
        if(-not $server){
            write-host 'server: ' -foregroundcolor green -nonewline
            $this.SERVER = Read-Host
            if(-not $this.SERVER){write-host 'server is required' -foregroundcolor red; break}
        }
        if(-not $username){
            write-host 'Username: ' -foregroundcolor green -nonewline
            $this.USERNAME = Read-Host
            if(-not $this.USERNAME){write-host 'username is required' -foregroundcolor red; break}
        }
        $this.APIROOT = 'https://' + $this.SERVER + '/irisservices/api/v1'
        $this.HEADER = @{'accept' = 'application/json'; 'content-type' = 'application/json'}
        $url = $this.APIROOT + '/public/accessTokens'
        if($updatePassword){
            $updatepw = '-updatePassword'
        }else{ 
            $updatepw = $null
        }
        try {
            if($global:UNIX){
            $auth = Invoke-RestMethod -Method Post -Uri $url  -Header $this.HEADER -Body $(
                ConvertTo-Json @{
                    'domain' = $this.DOMAIN; 
                    'password' = (getpwd $this.SERVER $this.USERNAME $this.DOMAIN $this.PASSWORD $updatepw); 
                    'username' = $this.USERNAME
                }) -SkipCertificateCheck
            $this.CURLHEADER = "authorization: $($auth.tokenType) $($auth.accessToken)"
            }else{
                $auth = Invoke-RestMethod -Method Post -Uri $url  -Header $this.HEADER -Body $(
                    ConvertTo-Json @{
                        'domain' = $this.DOMAIN; 
                        'password' = (getpwd $this.SERVER $this.USERNAME $this.DOMAIN $this.PASSWORD $updatepw); 
                        'username' = $this.USERNAME
                    })
                $this.WEBCLI = New-Object System.Net.WebClient;    
                $this.WEBCLI.Headers['authorization'] = $auth.tokenType + ' ' + $auth.accessToken;
            }
            $this.AUTHORIZED = $true
            $this.HEADER = @{'accept' = 'application/json'; 
                'content-type' = 'application/json'; 
                'authorization' = $auth.tokenType + ' ' + $auth.accessToken
            }
            if(!$quiet){ write-host "Connected!" -foregroundcolor green }
        }
        catch {
            $this.AUTHORIZED = $false
            if($_.ToString().contains('"message":')){
                write-host (ConvertFrom-Json $_.ToString()).message -foregroundcolor yellow
            }else{
                write-host $_.ToString() -foregroundcolor yellow
            }
        }
    }

    [System.Object] apicall($method, $uri, $data){
        if (-not $this.AUTHORIZED){ write-host 'Please use apiauth to connect to a cohesity cluster' -foregroundcolor yellow; break }
        #if (-not $methods.Contains($method)){ write-host "invalid api method: $method" -foregroundcolor yellow; break }
        try {
            if ($uri[0] -ne '/'){ $uri = '/public/' + $uri}
            $url = $this.APIROOT + $uri
            $body = ConvertTo-Json -Depth 100 $data
            if ($global:UNIX){
                $result = Invoke-RestMethod -Method $method -Uri $url -Body $body -Header $this.HEADER  -SkipCertificateCheck
            }else{
                $result = Invoke-RestMethod -Method $method -Uri $url -Body $body -Header $this.HEADER
            }
            return $result
        }
        catch {
            if($_.ToString().contains('"message":')){
                write-host (ConvertFrom-Json $_.ToString()).message -foregroundcolor yellow
            }else{
                write-host $_.ToString() -foregroundcolor yellow
            }
            return $null                
        }
    }

    [System.Object]get($uri){
        return $this.apicall('get',$uri,$null)
    }

    [System.Object]put($uri, $data){
        return $this.apicall('put',$uri,$data)
    }

    [System.Object]post($uri, $data){
        return $this.apicall('post',$uri,$data)
    }

    [System.Object]delete($uri, $data){
        return $this.apicall('delete',$uri,$data)
    }

    [String]getPwd(){
        return $(getpwd $this.SERVER $this.USERNAME $this.DOMAIN $this.PASSWORD)
    }

}

function connectCohesityCluster($server, $username, $domain='local', [string]$password=$null, [switch]$updatePassword=$false, [switch]$quiet=$false){
    return [CohesityCluster]::new($server, $username, $domain, $password, $updatePassword, $quiet)
}

# manage secure password
if ($global:UNIX) {

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

    function getpwd($vip, $username, $domain, $password, $updatePassword) {
        if($password){
            return $password
        }
        if ($domain -eq $null) { $domain = 'local'}
        $keyName = $vip + ':' + $domain + ':' + $username
        $keyFile = "$CONFDIR/$keyName"
        $storedPassword = $null
        $key = $null

        #get the encrypted password if it exists
        if ((Test-Path $keyFile) -eq $True) {
            $key, $storedPassword = get-content $keyFile
        }
        
        if ($updatePassword) { $storedPassword = $null }
        If (($storedPassword -ne $null) -and ($storedPassword.Length -ne 0) -and ($key -ne $null)) {
            $encryptedPassword = $storedPassword
            $clearTextPassword = Decrypt-String $key $encryptedPassword

            #else prompt the user for the password and store it in CONFDIR/keyFile for next time    
        }
        else {
            $secureString = Read-Host -Prompt "Enter password for $username at $vip" -AsSecureString
            $clearTextPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString))
            $key = Create-AesKey
            $key | Out-File $keyFile
            $encryptedPassword = Encrypt-String $key $clearTextPassword
            $encryptedPassword | Out-File $keyFile -Append
        }
    
        return $clearTextPassword
    }
}else{
    function getpwd($vip, $username, $domain, $password, $updatepPassword){
        if($password){
            return $password
        }
        $keyName = $vip + ':' + $domain + ':' + $username
        $registryPath = 'HKCU:\Software\Cohesity-API'
        $encryptedPasswordText = ''
    
        #get the encrypted password from the registry if it exists
        $storedPassword = Get-ItemProperty -Path "$registryPath" -Name "$keyName" -ErrorAction SilentlyContinue
        if($updatepassword){ $storedPassword = $null }
        If (($storedPassword -ne $null) -and ($storedPassword.Length -ne 0)) {
            $encryptedPasswordText = $storedPassword.$keyName
            $securePassword = $encryptedPasswordText  | ConvertTo-SecureString
    
        #else prompt the user for the password and store it in the registry for next time    
        }else{
            $securePassword = Read-Host -Prompt "Enter password for $username at $vip" -AsSecureString
            $encryptedPasswordText = $securePassword | ConvertFrom-SecureString
            if(!(Test-Path $registryPath)){
                New-Item -Path $registryPath -Force | Out-Null
            }
            Set-ItemProperty -Path "$registryPath" -Name "$keyName" -Value "$encryptedPasswordText"
        }
        
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
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


