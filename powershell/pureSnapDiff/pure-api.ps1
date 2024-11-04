# =====================================
#  PowerShell Module for Pure API
#  Version 2023.03.19 - Brian Seltzer
# =====================================
#
#  2022.03.19 - initial release
#  2023.10.10 - fixed exit behavior
#
# =====================================

# token authentication function =================================================================================
function papiauth($endpoint, $username, $version, $password=$null, [switch]$storePassword){
    # check available versions
    if(! $version){
        $url = "https://$($endpoint)/api/api_version"
        try{
            if($PSVersionTable.PSEdition -eq 'Core'){
                $api_versions = Invoke-RestMethod -Method Get -Uri $url -header $basic_api.headers -SkipCertificateCheck -TimeoutSec 300
            }else{
                $api_versions = Invoke-RestMethod -Method Get -Uri $url -header $basic_api.headers -TimeoutSec 300
            }
            $version = ($api_versions.version | Where-Object {$_ -lt 2})[-1]
        }catch{
            $thisError = $_
            if($thisError.ToString().contains('"msg":')){
                $msg = (ConvertFrom-Json $thisError.ToString()).msg
                Write-Host $msg -ForegroundColor Yellow
            }else{
                Write-Host $thisError.ToString() -ForegroundColor Yellow
            }
            return $null
        }
    }

    if(!$password){
        $password = pGet-APIPassword -endpoint $endpoint -username $username
        if(!$password){
            $password = pSet-APIPassword -endpoint $endpoint -username $username -storePassword $storePassword
        }
    }else{
        $password = pSet-APIPassword -endpoint $endpoint -username $username -passwd $password -storePassword $storePassword
    }

    # get an auth token
    $body = ConvertTo-Json @{
        'password' = $password;
        'username' = $username
    }
    $url = "https://$($endpoint)/api/$($version)/auth/apitoken"
    try{
        if($PSVersionTable.PSEdition -eq 'Core'){
            $auth = Invoke-RestMethod -Method Post -Uri $url -header $basic_api.headers -Body $body -SkipCertificateCheck -TimeoutSec 300
        }else{
            $auth = Invoke-RestMethod -Method Post -Uri $url -header $basic_api.headers -Body $body -TimeoutSec 300
        }
    }catch{
        $thisError = $_
        if($thisError.ToString().contains('"msg":')){
            $msg = (ConvertFrom-Json $thisError.ToString()).msg
            Write-Host $msg -ForegroundColor Yellow
        }else{
            Write-Host $thisError.ToString() -ForegroundColor Yellow
        }
        return $null
    }
    
    # get a session
    $body = ConvertTo-Json @{
        'api_token' = $auth.api_token
    }
    $url = "https://$($endpoint)/api/$($version)/auth/session"

    try{
        if($PSVersionTable.PSEdition -eq 'Core'){
            $session = Invoke-RestMethod -Method Post -Uri $url -header $basic_api.headers -Body $body -SkipCertificateCheck -TimeoutSec 300 -SessionVariable SessionVar
        }else{
            $session = Invoke-RestMethod -Method Post -Uri $url -header $basic_api.headers -Body $body -TimeoutSec 300 -SessionVariable SessionVar
        }
        if($session){
            Write-Host "Connected!" -ForegroundColor Green
        }else{
            Write-Host "Not Connected" -ForegroundColor Yellow
            return $null
        }
    }catch{
        Write-Host "Not Connected" -ForegroundColor Yellow
        return $null
    }

    $basic_api.base_url = "https://$($endpoint)/api/$($version)/"
    $basic_api.session = $SessionVar 
}

# logout
function papidrop(){
    Write-Host "Disconnected" -ForegroundColor Green
    $deleteSession = papi delete auth/session
    $basic_api = @{
        'base_url' = '';
        'headers' = @{'accept' = 'application/json'; 'Content-Type' = 'application/json'}
        'session' = $null
    }
}

# api call function =======================================================================================
function papi($method, $uri, $data=$null){
    $uri = $basic_api.base_url + $uri
    $result = $null
    try{
        if($data){
            $BODY = ConvertTo-Json $data -Depth 99
            if($PSVersionTable.PSEdition -eq 'Core'){
                $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $basic_api.headers -Body $BODY -SkipCertificateCheck -WebSession $basic_api.session
            }else{
                $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $basic_api.headers -Body $BODY -WebSession $basic_api.session
            }
        }else{
            if($PSVersionTable.PSEdition -eq 'Core'){
                $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $basic_api.headers -SkipCertificateCheck -WebSession $basic_api.session
            }else{
                $result = Invoke-RestMethod -Uri $uri -Method $method -Headers $basic_api.headers -WebSession $basic_api.session
            }
        }
    }catch{
        if($_.ToString().contains('"errors" :')){
            Write-Host (ConvertFrom-Json $_.ToString()).errors[0].message -foregroundcolor Yellow
        }else{
            Write-Host $_.ToString() -foregroundcolor yellow
        }
    }
    return $result
}

# date functions ==========================================================================================

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

function dateToUsecs($datestring=(Get-Date)){
    if($datestring -isnot [datetime]){ $datestring = [datetime] $datestring }
    $usecs = [int64](($datestring.ToUniversalTime())-([datetime]"1970-01-01 00:00:00")).TotalSeconds*1000000
    return $usecs
}

function usecsToDate($usecs, $format=$null){
    $unixTime=$usecs/1000000
    $origin = ([datetime]'1970-01-01 00:00:00')
    if($format){
        return $origin.AddSeconds($unixTime).ToLocalTime().ToString($format)
    }else{
        return $origin.AddSeconds($unixTime).ToLocalTime()
    }
}

# password storage functions ==============================================================================

function pGet-APIPassword($endpoint, $username){
    if($endpoint -match ':'){
        $endpoint = $endpoint.replace(':','--')
    }
    $keyName = "$endpoint`-$username"
    if($PSVersionTable.Platform -eq 'Unix'){
        # Unix
        $keyFile = "$CONFDIR/$keyName"
        if(Test-Path $keyFile){
            $cpwd = Get-Content $keyFile
            return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cpwd))
        }
    }else{
        # Windows
        $storedPassword = Get-ItemProperty -Path "$registryPath" -Name "$keyName" -ErrorAction SilentlyContinue
        if(($null -ne $storedPassword) -and ($storedPassword.Length -ne 0)){
            if( $null -ne $storedPassword.$keyName -and $storedPassword.$keyName -ne ''){
                $securePassword = $storedPassword.$keyName  | ConvertTo-SecureString
                return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $securePassword ))
            }
        }
    }
    return $null
}

function pSet-APIPassword($endpoint, $username, $passwd=$null, $storePassword = $false){

    if(!$passwd){
        $secureString = Read-Host -Prompt "Enter password for $username@$endpoint" -AsSecureString
        $passwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
    }
    $opwd = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($passwd))

    if($endpoint -match ':'){
        $endpoint = $endpoint.replace(':','--')
    }

    if($storePassword -eq $True){
        $keyName = "$endpoint`-$username"
        if($PSVersionTable.Platform -eq 'Unix'){
            # Unix
            $keyFile = "$CONFDIR/$keyName"
            $opwd | Out-File $keyFile
        }else{
            # Windows
            if($null -ne $passwd -and $passwd -ne ''){
                $securePassword = ConvertTo-SecureString -String $passwd -AsPlainText -Force
                $encryptedPasswordText = $securePassword | ConvertFrom-SecureString
                if(!(Test-Path $registryPath)){
                    New-Item -Path $registryPath -Force | Out-Null
                }
                Set-ItemProperty -Path "$registryPath" -Name "$keyName" -Value "$encryptedPasswordText" -Force
            }
        }
    }

    return $passwd
}

# initialization ==========================================================================================

# demand modern powershell version (must support TLSv1.2)
if($Host.Version.Major -le 5 -and $Host.Version.Minor -lt 1){
    Write-Warning "PowerShell version must be upgraded to 5.1 or higher to connect to Cohesity!"
    Pause
    exit
}

# handle unsigned certificates
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

$basic_api = @{
    'base_url' = '';
    'headers' = @{'accept' = 'application/json'; 'Content-Type' = 'application/json'}
    'session' = $null
}

if($PSVersionTable.Platform -ne 'Unix'){
    $registryPath = 'HKCU:\Software\Basic-API' 
}else{
    $CONFDIR = '~/.basic-api'
    if($(Test-Path $CONFDIR) -eq $false){ $null = New-Item -Type Directory -Path $CONFDIR}
}
