# =====================================
#  PowerShell Module for Isilon API
#  Version 2024.05.30 - Brian Seltzer
# =====================================
#
#  2024.05.30 - initial release
#
# =====================================


# authentication function =================================================================================
function isilonAuth($endpoint, $username, $password=$null){
    if(!$password){
        $password = Get-APIPassword -endpoint $endpoint -username $username
        if(!$password){
            $password = Set-APIPassword -endpoint $endpoint -username $username
        }
    }else{
        $password = Set-APIPassword -endpoint $endpoint -username $username -passwd $password
    }
    $BODY = ConvertTo-Json @{
        "username" = $username;
        "password" = $password;
        "services" = @(
            "platform",
            "namespace",
            "remote-service"
        )
    }
    $uri = "https://$($endpoint)/session/1/session"
    if($PSVersionTable.PSEdition -eq 'Core'){
        $result = Invoke-RestMethod -Uri $uri -Method Post -Headers $basic_api.headers -Body $BODY -SkipCertificateCheck -SessionVariable session
    }else{
        $result = Invoke-RestMethod -Uri $uri -Method Post -Headers $basic_api.headers -Body $BODY -SessionVariable session
    }
    $basic_api.base_url = "https://$($endpoint)"
    $basic_api.session = $session
    if($PSVersionTable.PSEdition -eq 'Core'){
        $cookies = $session.Cookies.GetAllCookies()
    }else{
        $cookies = $session.Cookies.GetCookies($uri)
    }
    $basic_api.headers['isisessid'] = ($cookies | Where-Object name -eq 'isisessid').Value
    $basic_api.headers['X-CSRF-Token'] = ($cookies | Where-Object name -eq 'isicsrf').Value
    $basic_api.headers['referer'] = $basic_api.base_url
}

# api call function =======================================================================================
function isilonApi($method, $uri, $data=$null){
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

function Get-APIPassword($endpoint, $username){
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

function Set-APIPassword($endpoint, $username, $passwd=$null){

    if(!$passwd){
        $secureString = Read-Host -Prompt "Enter password for $username@$endpoint" -AsSecureString
        $passwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
    }
    $opwd = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($passwd))

    if($endpoint -match ':'){
        $endpoint = $endpoint.replace(':','--')
    }

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
    'headers' = @{'accept' = 'application/json'; 'content-type' = 'application/json'};
    'session' = $null
}

if($PSVersionTable.Platform -ne 'Unix'){
    $registryPath = 'HKCU:\Software\Basic-API' 
}else{
    $CONFDIR = '~/.basic-api'
    if($(Test-Path $CONFDIR) -eq $false){ $null = New-Item -Type Directory -Path $CONFDIR}
}
