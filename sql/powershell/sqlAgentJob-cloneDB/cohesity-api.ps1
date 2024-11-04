# . . . . . . . . . . . . . . . . . . .
#  PowerShell Module for Cohesity API
#  Version 2022.02.10 - Brian Seltzer
# . . . . . . . . . . . . . . . . . . .
#
# 2021.02.10 - fixed empty body issue
# 2021.03.26 - added apiKey unique password storage
# 2021.08.16 - revamped passwd storage, auto prompt for invalid password
# 2021.09.23 - added support for Ccs, Helios Reporting V2
# 2021.10.14 - added storePasswordForUser and importStoredPassword
# 2021.10.22 - fixed json2code and py functions and added toJson function
# 2021.11.03 - fixed 'Cannot send a content-body with this verb-type' message in debug log
# 2021.11.10 - added getContext, setContext
# 2021.11.15 - added support for helios on prem
# 2021.11.18 - added support for multifactor authentication
# 2021.12.07 - added support for email multifactor authentication
# 2021.12.11 - added date formatting to usecsToDate function and dateToUsecs defaults to now
# 2021.12.17 - auto import shared password into user password storage
# 2021.12.21 - fixed USING_HELIOS status flag
# 2022.01.12 - fixed storePasswordForUser
# 2022.01.27 - changed password storage for non-Windows, added wildcard vip for AD accounts
# 2022.01.29 - fixed helios on-prem password storage, heliosCluster function
# 2022.02.04 - added support for V2 session authentiation
# 2022.02.10 - fixed bad password handling
#
# . . . . . . . . . . . . . . . . . . .
$versionCohesityAPI = '2022.02.10'

# demand modern powershell version (must support TLSv1.2)
if($Host.Version.Major -le 5 -and $Host.Version.Minor -lt 1){
    Write-Warning "PowerShell version must be upgraded to 5.1 or higher to connect to Cohesity!"
    Pause
    exit
}

# state cache
$cohesity_api = @{
    'reportApiErrors' = $true;
    'authorized' = $false;
    'apiRoot' = '';
    'apiRootv2' = '';
    'regionid' = '';
    'apiRootmcm' = '';
    'apiRootmcmV2' = ''
    'apiRootReportingV2' = '';
    'header' = @{'accept' = 'application/json'; 'content-type' = 'application/json'};
    'clusterReadOnly' = $false;
    'heliosConnectedClusters' = $null;
    'curlHeader' = @();
    'webcli' = $null;
    'version' = 1;
    'pwscope' = 'user';
}

$pwfile = $(Join-Path -Path $PSScriptRoot -ChildPath YWRtaW4)
$apilogfile = $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api-debug.log)

# platform detection ==========================================================================

if($PSVersionTable.Platform -ne 'Unix'){
    $cohesity_api.webcli = New-Object System.Net.webclient;
    $registryPath = 'HKCU:\Software\Cohesity-API' 
}else{
    $CONFDIR = '~/.cohesity-api'
    if($(Test-Path $CONFDIR) -eq $false){ $null = New-Item -Type Directory -Path $CONFDIR}
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

function apiauth($vip='helios.cohesity.com', 
                 $username = 'helios', 
                 $domain = 'local', 
                 $passwd = $null,
                 $password = $null,
                 $tenant = $null,
                 $regionid = $null,
                 $mfaType = 'Totp',
                 [string] $mfaCode = $null,
                 [switch] $emailMfaCode,
                 [switch] $helios,
                 [switch] $quiet, 
                 [switch] $noprompt, 
                 [switch] $updatePassword, 
                 [switch] $useApiKey,
                 [switch] $v2){

    # parse domain\username or username@domain
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    if($password){ $passwd = $password }
    # update password
    if($updatePassword -or $clearPassword){
        $passwd = Set-CohesityAPIPassword -vip $vip -username $username -domain $domain -passwd $passwd -quiet -useApiKey $useApiKey -helios $helios
    }
    # get stored password
    if(!$passwd){
        $passwd = Get-CohesityAPIPassword -vip $vip -username $username -domain $domain -useApiKey $useApiKey -helios $helios
        if(!$passwd -and !$noprompt){
            # prompt for password and store
            $passwd = Set-CohesityAPIPassword -vip $vip -username $username -domain $domain -quiet -useApiKey $useApiKey -helios $helios
        }
        if(!$passwd){
            # report no password
            Write-Host "No password provided for $username at $vip" -ForegroundColor Yellow
            apidrop -quiet
            break
        }
    }

    $cohesity_api.header = @{'accept' = 'application/json'; 'content-type' = 'application/json'}

    $body = ConvertTo-Json @{
        'domain' = $domain;
        'username' = $username;
        'password' = $passwd;
        'otpType' = $mfaType;
        'otpCode' = $mfaCode
    }

    $emailMfaBody = ConvertTo-Json @{
        'domain' = $domain;
        'username' = $username;
        'password' = $passwd;
    }

    $cohesity_api.apiRoot = 'https://' + $vip + '/irisservices/api/v1'
    $cohesity_api.apiRootv2 = 'https://' + $vip + '/v2/'
    $cohesity_api.apiRootmcm = "https://$vip/mcm/"
    $cohesity_api.apiRootmcmV2 = "https://$vip/v2/mcm/"
    $cohesity_api.apiRootReportingV2 = "https://$vip/heliosreporting/api/v1/public/"

    $cohesity_api.version = 1
    if($v2){
        $cohesity_api.version = 2
    }

    if($regionid){
        $cohesity_api.header['regionid'] = $regionid
    }

    if($useApiKey -or $helios -or ($vip -eq 'helios.cohesity.com')){
        $cohesity_api.header['apiKey'] = $passwd
        $cohesity_api.authorized = $true
        # set file transfer details
        if($PSVersionTable.Platform -eq 'Unix'){
            $cohesity_api.curlHeader = @("apiKey: $passwd")
        }else{
            $cohesity_api.webcli.headers['apiKey'] = $passwd;
        }
        # validate cluster authorization
        if($useApiKey -and (($vip -ne 'helios.cohesity.com') -and $helios -ne $True)){
            $cluster = api get cluster -quiet -version 1 -data $null
            if($cluster.clusterSoftwareVersion -lt '6.4'){
                $cohesity_api.version = 1
            }
            if($cluster){
                if(!$quiet){ Write-Host "Connected!" -foregroundcolor green }
            }else{
                Write-Host "api key authentication failed" -ForegroundColor Yellow
                apidrop -quiet
                apiauth -vip $vip -username $username -domain $domain -useApiKey -updatePassword
            }
        }
        # validate helios authorization
        if($vip -eq 'helios.cohesity.com' -or $helios){
            try{
                $URL = $cohesity_api.apiRootmcm + 'clusters/connectionStatus'
                if($PSVersionTable.PSEdition -eq 'Core'){
                    $heliosAllClusters = Invoke-RestMethod -Method get -Uri $URL -header $cohesity_api.header -SkipCertificateCheck
                }else{
                    $heliosAllClusters = Invoke-RestMethod -Method get -Uri $URL -header $cohesity_api.header
                }
                $cohesity_api.heliosConnectedClusters = $heliosAllClusters | Where-Object {$_.connectedToCluster -eq $true}
                $cohesity_api.authorized = $true
                $Global:USING_HELIOS = $true
                $Global:USING_HELIOS | Out-Null
                if(!$quiet){ Write-Host "Connected!" -foregroundcolor green }
            }catch{
                Write-Host "helios authentication failed" -ForegroundColor Yellow
                apidrop -quiet
                apiauth -vip $vip -username $username -domain $domain -updatePassword
            }
        }
    }else{
        $Global:USING_HELIOS = $false
        $Global:USING_HELIOS | Out-Null
        $url = $cohesity_api.apiRoot + '/public/accessTokens'
        try {
            if($emailMfaCode){
                $emailUrl = $cohesity_api.apiRootv2 + 'email-otp'
                if($PSVersionTable.PSEdition -eq 'Core'){
                    $email = Invoke-RestMethod -Method Post -Uri $emailUrl -header $cohesity_api.header -Body $emailMfaBody -SkipCertificateCheck
                }else{
                    $email = Invoke-RestMethod -Method Post -Uri $emailUrl -header $cohesity_api.header -Body $emailMfaBody
                }
                $mfaCode = Read-Host -Prompt "Enter emailed MFA code"
                $body = ConvertTo-Json @{
                    'domain' = $domain;
                    'username' = $username;
                    'password' = $passwd;
                    'otpType' = 'Email';
                    'otpCode' = $mfaCode
                }
            }
            # authenticate
            if($PSVersionTable.PSEdition -eq 'Core'){
                $auth = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -Body $body -SkipCertificateCheck
            }else{
                $auth = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -Body $body
            }
            # set file transfer details
            if($PSVersionTable.Platform -eq 'Unix'){
                $cohesity_api.curlHeader = @("authorization: $($auth.tokenType) $($auth.accessToken)")
            }else{
                $cohesity_api.webcli.headers['authorization'] = $auth.tokenType + ' ' + $auth.accessToken;
            }
            # add token to header
            $cohesity_api.authorized = $true
            $cohesity_api.clusterReadOnly = $false
            $cohesity_api.header = @{'accept' = 'application/json'; 
                'content-type' = 'application/json'; 
                'authorization' = $auth.tokenType + ' ' + $auth.accessToken
            }
            $cluster = api get cluster -quiet -version 1 -data $null
            if($cluster.clusterSoftwareVersion -lt '6.4'){
                $cohesity_api.version = 1
            }
            if(!$quiet){ Write-Host "Connected!" -foregroundcolor green }
        }catch{
            $thisError = $_
            # try v2 session auth
            if($thisError.ToString().contains('"message":')){
                $message = (ConvertFrom-Json $thisError.ToString()).message
                if($message -eq 'Access denied'){
                    try{
                        $url = $cohesity_api.apiRootv2 + 'users/sessions'
                        $body = ConvertTo-Json @{
                            'domain' = $domain;
                            'username' = $username;
                            'password' = $passwd
                        }
                        # authenticate
                        if($PSVersionTable.PSEdition -eq 'Core'){
                            $auth = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -Body $body -SkipCertificateCheck
                        }else{
                            $auth = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -Body $body
                        }
                        # set file transfer details
                        if($PSVersionTable.Platform -eq 'Unix'){
                            $cohesity_api.curlHeader = @("session-id: $($auth.sessionId)")
                        }else{
                            $cohesity_api.webcli.headers['session-id'] = $auth.sessionId;
                        }
                        # add token to header
                        $cohesity_api.authorized = $true
                        $cohesity_api.clusterReadOnly = $false
                        $cohesity_api.header = @{'accept' = 'application/json'; 
                            'content-type' = 'application/json'; 
                            'session-id' = $auth.sessionId
                        }
                        $cluster = api get cluster -quiet -version 1 -data $null
                        if($cluster.clusterSoftwareVersion -lt '6.4'){
                            $cohesity_api.version = 1
                        }
                        if(!$quiet){
                            Write-Host "Connected!" -foregroundcolor green
                        }
                    }catch{
                        apidrop -quiet
                        __writeLog $thisError.ToString()
                        if($cohesity_api.reportApiErrors){
                            if($thisError.ToString().contains('"message":')){
                                $message = (ConvertFrom-Json $_.ToString()).message
                                Write-Host $message -foregroundcolor yellow
                                if($message -match 'Invalid Username or Password'){
                                    apiauth -vip $vip -username $username -domain $domain -updatePassword
                                }
                            }else{
                                Write-Host $thisError.ToString() -foregroundcolor yellow
                            }
                        }
                        break
                    }
                }else{
                    # report authentication error
                    apidrop -quiet
                    __writeLog $thisError.ToString()
                    $message = (ConvertFrom-Json $_.ToString()).message
                    if($cohesity_api.reportApiErrors){
                        Write-Host $message -foregroundcolor yellow
                        if($message -match 'Invalid Username or Password'){
                            apiauth -vip $vip -username $username -domain $domain -updatePassword
                        }
                    }
                }
            }else{
                # report authentication error
                apidrop -quiet
                __writeLog $thisError.ToString()
                if($cohesity_api.reportApiErrors){
                    if($thisError.ToString().contains('"message":')){
                        $message = (ConvertFrom-Json $_.ToString()).message
                        Write-Host $message -foregroundcolor yellow
                        if($message -match 'Invalid Username or Password'){
                            apiauth -vip $vip -username $username -domain $domain -updatePassword
                        }
                    }else{
                        Write-Host $thisError.ToString() -foregroundcolor yellow
                    }
                }
            }
        }
    }
    if($tenant){
        impersonate $tenant
    }
    $Global:AUTHORIZED = $cohesity_api.authorized
    $Global:AUTHORIZED | Out-Null
}

# select helios access cluster
function heliosCluster($clusterName){
    if($clusterName -and $cohesity_api.heliosConnectedClusters){
        # connect to cluster
        if(! ($clusterName -is [string])){
            $clusterName = $clusterName.name
        }
        $cluster = $cohesity_api.heliosConnectedClusters | Where-Object {$_.name -eq $clusterName}
        if($cluster){
            $cohesity_api.header.accessClusterId = $cluster.clusterId
            $cohesity_api.header.clusterId = $cluster.clusterId
            $cohesity_api.clusterReadOnly = (api get /mcm/config -version 1).mcmReadOnly
            if($PSVersionTable.Platform -eq 'Unix'){
                $cohesity_api.curlHeader = @($cohesity_api.curlHeader | Where-Object {$_.subString(0,9) -ne 'accessClu' -and $_.subString(0,9) -ne 'clusterId'})
                $cohesity_api.curlHeader += "accessClusterId: $($cluster.clusterId)"
                $cohesity_api.curlHeader += "clusterId: $($cluster.clusterId)"
            }else{
                $cohesity_api.webcli.headers['accessClusterId'] = $cluster.clusterId;
                $cohesity_api.webcli.headers['clusterId'] = $cluster.clusterId;
            }
            return "Connected to $clusterName"
        }else{
            Write-Host "Cluster $clusterName not connected to Helios" -ForegroundColor Yellow
            $cohesity_api.header.remove('accessClusterId')
            $cohesity_api.header.remove('clusterId')
            if($PSVersionTable.Platform -eq 'Unix'){
                $cohesity_api.curlHeader = @($cohesity_api.curlHeader | Where-Object {$_.subString(0,9) -ne 'accessClu' -and $_.subString(0,9) -ne 'clusterId'})
            }else{
                $cohesity_api.webcli.headers.remove('accessClusterId')
                $cohesity_api.webcli.headers.remove('clusterId')
            }
            return $null
        }
    }else{
        # display list of helios connected clusters
        $cohesity_api.heliosConnectedClusters | Sort-Object -Property name | Select-Object -Property name, clusterId, softwareVersion
        "`ntype heliosCluster <clustername> to connect to a cluster"
    }
    if(-not $cohesity_api.authorized){ 
        if($cohesity_api.reportApiErrors){
            Write-Host 'Please use apiauth to connect to helios' -foregroundcolor yellow
        }
    }
}

function heliosClusters(){
    return $cohesity_api.heliosConnectedClusters | Sort-Object -Property name
}

# terminate authentication
function apidrop([switch] $quiet){
    $cohesity_api.authorized = $false
    $cohesity_api.apiRoot = ''
    $cohesity_api.apiRootv2 = ''
    $cohesity_api.header = @{'accept' = 'application/json'; 'content-type' = 'application/json'}
    $cohesity_api.clusterReadOnly = $false
    $cohesity_api.heliosConnectedClusters = $null
    $cohesity_api.curlHeader = @()
    if($cohesity_api.webcli){
        $cohesity_api.webcli = New-Object System.Net.webclient
    }
    if(!$quiet){ Write-Host "Disonnected!" -foregroundcolor green }
    $Global:AUTHORIZED = $cohesity_api.authorized
    $Global:AUTHORIZED | Out-Null
    $Global:USING_HELIOS = $false
    $Global:USING_HELIOS | Out-Null
}

function impersonate($tenant){
    if($cohesity_api.authorized){ 
        $thisTenant = api get tenants -version 1 | Where-Object {$_.name -eq $tenant}
        if($thisTenant){
            $cohesity_api.header['x-impersonate-tenant-id'] = $thisTenant.tenantId
            if($PSVersionTable.Platform -eq 'Unix'){
                $cohesity_api.curlHeader += @("x-impersonate-tenant-id: $($thisTenant.tenantId)")
            }else{
                $cohesity_api.webcli.headers['x-impersonate-tenant-id'] = $thisTenant.tenantId;
            }
        }else{
            Write-Host "Tenant $tenant not found" -ForegroundColor Yellow
        }
    }else{
        Write-Host 'Not authenticated to a cohesity cluster' -foregroundcolor yellow
    }
}

function switchback(){
    $cohesity_api.header.Remove('x-impersonate-tenant-id')
}

function getContext(){
    return $cohesity_api.Clone()
}

function setContext($context){
    if($context['header'] -and $context['apiRoot'] -and $context['apiRootv2']){
        $Global:cohesity_api = $context.Clone()
    }else{
        Write-Host "Invalid context" -ForegroundColor Yellow
    }
}

# api call function ==============================================================================

$methods = 'get', 'post', 'put', 'delete', 'patch'
function api($method, 
             $uri, 
             $data, 
             [ValidateRange(0,2)][Int]$version=0,
             [switch]$v1, 
             [switch]$v2,
             [switch]$mcm,
             [switch]$mcmv2,
             [switch]$reportingV2,
             [switch]$quiet){

    if($method -eq 'get'){
        $body = $null
        $data = $null
    }

    if(-not $cohesity_api.authorized){ 
        if($cohesity_api.reportApiErrors){
            Write-Host 'Not authenticated to a cohesity cluster' -foregroundcolor yellow
            if($MyInvocation.PSCommandPath){
                exit 1
            }
        }
    }else{
        if($method -ne 'get' -and $cohesity_api.clusterReadOnly -eq $true){
            Write-Host "Cluster connection is READ-ONLY" -ForegroundColor Yellow
            break
        }
        if(-not $methods.Contains($method)){
            if($cohesity_api.reportApiErrors){
                Write-Host "invalid api method: $method" -foregroundcolor yellow
            }
            break
        }
        # use api version
        if(!$version){
            if($cohesity_api.version -notin @(1,2)){
                $version = 1
            }else{
                $version = $cohesity_api.version
            }
        }
        if($v2){
            $version = 2
        }
        if($v1){
            $version = 1
        }
        if($version -eq 2){
            $url = $cohesity_api.apiRootv2 + $uri
        }elseif($mcm){
            $url = $cohesity_api.apiRootmcm + $uri
        }elseif($mcmv2){
            $url = $cohesity_api.apiRootmcmV2 + $uri
        }elseif($reportingV2){
            $url = $cohesity_api.apiRootReportingV2 + $uri            
        }else{
            if($uri[0] -ne '/'){ $uri = '/public/' + $uri}
            $url = $cohesity_api.apiRoot + $uri
        }
        if($url -match ' ' -and $url -notmatch '%'){
            $url = [uri]::EscapeUriString($url)
        }
        try {
            if($data){
                $body = ConvertTo-Json -Compress -Depth 99 $data
            }
            if($PSVersionTable.PSEdition -eq 'Core'){
                if($body){
                    $result = Invoke-RestMethod -Method $method -Uri $url -Body $body -header $cohesity_api.header -SkipCertificateCheck
                }else{
                    $result = Invoke-RestMethod -Method $method -Uri $url -header $cohesity_api.header -SkipCertificateCheck
                }
            }else{
                if($body){
                    $result = Invoke-RestMethod -Method $method -Uri $url -Body $body -header $cohesity_api.header
                }else{
                    $result = Invoke-RestMethod -Method $method -Uri $url -header $cohesity_api.header
                }
            }
            return $result
        }catch{
            __writeLog $_.ToString()
            if($cohesity_api.reportApiErrors -and !$quiet){
                if($_.ToString().contains('"message":')){
                    Write-Host (ConvertFrom-Json $_.ToString()).message -foregroundcolor yellow
                }else{
                    Write-Host $_.ToString() -foregroundcolor yellow
                }
            }            
        }
    }
}

# file download function ========================================================================

function fileDownload($uri, $fileName, $version=1, [switch]$v2){

    if(-not $cohesity_api.authorized){ Write-Host 'Please use apiauth to connect to a cohesity cluster' -foregroundcolor yellow; break }
    try {
        if($version -eq 2 -or $v2){
            $url = $cohesity_api.apiRootv2 + $uri
        }else{
            if($uri[0] -ne '/'){ $uri = '/public/' + $uri}
            $url = $cohesity_api.apiRoot + $uri
        }
        if($PSVersionTable.Platform -eq 'Unix'){
            $ch = ''
            foreach($h in $cohesity_api.curlHeader){
                $ch += '-H "' + $h + '" '
            }
            Invoke-Expression -Command "curl -k -s $ch -o $fileName $url"
        }else{
            if($fileName -notmatch '\\'){
                $fileName = $(Join-Path -Path $PSScriptRoot -ChildPath $fileName)
            }
            $cohesity_api.webcli.DownloadFile($url, $fileName)
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

function usecsToDate($usecs, $format=$null){
    $unixTime=$usecs/1000000
    $origin = ([datetime]'1970-01-01 00:00:00')
    if($format){
        return $origin.AddSeconds($unixTime).ToLocalTime().ToString($format)
    }else{
        return $origin.AddSeconds($unixTime).ToLocalTime()
    }
}

function dateToUsecs($datestring=(Get-Date)){
    if($datestring -isnot [datetime]){ $datestring = [datetime] $datestring }
    $usecs = [int64](($datestring.ToUniversalTime())-([datetime]"1970-01-01 00:00:00")).TotalSeconds*1000000
    $usecs
}

# password functions ==============================================================================

function Get-CohesityAPIPassword($vip='helios.cohesity.com', $username='helios', $domain='local', $useApiKey=$false, $helios=$false){
    # parse domain\username or username@domain
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    if($domain -ne 'local' -and $helios -eq $false -and $vip -ne 'helios.cohesity.com' -and $useApiKey -eq $false){
        $vip = '--'  # wildcard vip for AD accounts
    }
    $keyName = "$vip`-$domain`-$username`-$useApiKey"
    $altKeyName = "$vip`:$domain`:$username`:$useApiKey"
    if($PSVersionTable.Platform -eq 'Unix'){
        # Unix
        $keyFile = "$CONFDIR/$keyName"
        if(Test-Path $keyFile){
            $cohesity_api.pwscope = 'user'
            $cpwd = Get-Content $keyFile
            return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cpwd))
        }
        # old format
        $altKeyFile = "$CONFDIR/$altKeyName"
        if(Test-Path $altKeyFile){
            $cohesity_api.pwscope = 'user'
            $cpwd = Get-Content $altKeyFile
            return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cpwd))
        }
    }else{
        # Windows
        $storedPassword = Get-ItemProperty -Path "$registryPath" -Name "$keyName" -ErrorAction SilentlyContinue
        # old format
        if(($null -eq $storedPassword) -or ($storedPassword.Length -eq 0)){
            $storedPassword = Get-ItemProperty -Path "$registryPath" -Name "$altKeyName" -ErrorAction SilentlyContinue
            $keyName = $altKeyName
        }
        if(($null -ne $storedPassword) -and ($storedPassword.Length -ne 0)){
            $cohesity_api.pwscope = 'user'
            if( $null -ne $storedPassword.$keyName -and $storedPassword.$keyName -ne ''){
                $securePassword = $storedPassword.$keyName  | ConvertTo-SecureString
                return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $securePassword ))
            }
        }
    }

    $pwlist = Get-Content -Path $pwfile -ErrorAction SilentlyContinue
    foreach($pwitem in $pwlist){
        $parts = $pwitem.split(";", 5)
        $v = $parts[0]
        $d = $parts[1]
        $u = $parts[2]
        if($parts.Count -gt 4){
            $i = $parts[3]
            $cpwd = $parts[4]
        }else{
            $i = $false
            $cpwd = $parts[3]
        }
        # $v, $d, $u, $i, $cpwd = $pwitem.split(";", 5)
        if($v -eq $vip -and $d -eq $domain -and $u -eq $username -and $i -eq $useApiKey){
            $cohesity_api.pwscope = 'file'
            $passwd = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cpwd))
            $cohesity_api.pwscope = 'user'
            $null = Set-CohesityAPIPassword -vip $vip -username $username -domain $domain -useApiKey $useApiKey -helios $helios -passwd $passwd -quiet
            return $passwd
        }
    }
    return $null
}

function Clear-CohesityAPIPassword($vip='helios.cohesity.com', $username='helios', $domain='local', [switch]$quiet, $useApiKey=$false, $helios=$false){
    # parse domain\username or username@domain
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    if($domain -ne 'local' -and !$helios -and $vip -ne 'helios.cohesity.com' -and $useApiKey -eq $false){
        $vip = '--'  # wildcard vip for AD accounts
    }
    $keyName = "$vip`-$domain`-$username`-$useApiKey"
    $altKeyName = "$vip`:$domain`:$username"

    # remove old passwords from user scope pw storage
    if($PSVersionTable.Platform -eq 'Unix'){
        # Unix
        $keyFile = "$CONFDIR/$keyName"
        $altKeyFile = "$CONFDIR/$altKeyName"
        if(Test-Path $keyFile){
            Remove-Item -Path $keyFile -Force -ErrorAction SilentlyContinue
        }
        if(Test-Path $altKeyFile){
            Remove-Item -Path $altKeyFile -Force -ErrorAction SilentlyContinue
        }
    }else{
        # Windows
        Remove-ItemProperty -Path "$registryPath" -Name "$keyName" -ErrorAction SilentlyContinue -Force
        Remove-ItemProperty -Path "$registryPath" -Name "$altKeyName" -ErrorAction SilentlyContinue -Force
    }

    # remove old passwords from pwfile
    $pwlist = Get-Content -Path $pwfile -ErrorAction SilentlyContinue
    $updatedContent = ''
    $foundPwd = $false
    foreach($pwitem in ($pwlist | Sort-Object)){
        $v, $d, $u, $i, $cpwd = $pwitem.split(";", 5)
        if($null -eq $cpwd){
            $i = $false
        }
        if($v -ne $vip -or $d -ne $domain -or $u -ne $username -or $i -ne $useApiKey){
            if($pwitem -ne ''){
                $updatedContent += "{0}`n" -f $pwitem
            }
        }
    }
    $updatedContent | out-file -FilePath $pwfile
}

function Set-CohesityAPIPassword($vip='helios.cohesity.com', $username='helios', $domain='local', $passwd=$null, [switch]$quiet, $useApiKey=$false, $helios=$false){

    Clear-CohesityAPIPassword -vip $vip -username $username -domain $domain -useApiKey $useApiKey -helios $helios

    # parse domain\username or username@domain
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    if($domain -ne 'local' -and !$helios -and $vip -ne 'helios.cohesity.com' -and $useApiKey -eq $false){
        $vip = '--'  # wildcard vip for AD accounts
    }
    if(!$passwd){
        __writeLog "Prompting for Password"
        $secureString = Read-Host -Prompt "Enter your password" -AsSecureString
        $passwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
    }
    $opwd = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($passwd))

    $keyName = "$vip`-$domain`-$username`-$useApiKey"
    if($cohesity_api.pwscope -eq 'user'){
        # write to user-specific storage
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
                Set-ItemProperty -Path "$registryPath" -Name "$keyName" -Value "$encryptedPasswordText"
            }
        }
    }else{
        $pwlist = Get-Content -Path $pwfile -ErrorAction SilentlyContinue
        $updatedContent = ''
        $foundPwd = $false
        foreach($pwitem in ($pwlist | Sort-Object)){
            $v, $d, $u, $i, $cpwd = $pwitem.split(";", 5)
            if($null -eq $cpwd){
                $i = $false
            }
            # update existing
            if($v -eq $vip -and $d -eq $domain -and $u -eq $username -and $i -eq $useApiKey){
                $foundPwd = $true
                $updatedContent += "{0};{1};{2};{3};{4}`n" -f $vip, $domain, $username, $useApiKey, $opwd
            # other existing records
            }else{
                if($pwitem -ne ''){
                    $updatedContent += "{0}`n" -f $pwitem
                }
            }
        }
        # add new
        if(!$foundPwd){
            $updatedContent += "{0};{1};{2};{3};{4}`n" -f $vip, $domain, $username, $useApiKey, $opwd
        }
        $updatedContent | out-file -FilePath $pwfile
    }

    if(!$quiet){ Write-Host "Password stored!" -ForegroundColor Green }
    return $passwd
}

function storePasswordInFile($vip='helios.cohesity.com', $username='helios', $domain='local', $passwd=$null, [switch]$useApiKey){
    $cohesity_api.pwscope = 'file'
    $null = Set-CohesityAPIPassword -vip $vip -username $username -domain $domain -passwd $passwd -useApiKey $useApiKey -helios $helios
}

function storePasswordForUser($vip='helios.cohesity.com', $username='helios', $domain='local', $passwd=$null){
    $userFile = $(Join-Path -Path $PSScriptRoot -ChildPath "pw-$vip-$username-$domain.txt")
    $keyString = (Get-Random -Minimum 10000000000000 -Maximum 99999999999999).ToString()
    $keyBytes = [byte[]]($keyString -split(''))
    if($null -eq $passwd){
        $secureString = Read-Host -Prompt "Enter your password" -AsSecureString
        $passwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
        $secureString = Read-Host -Prompt "Confirm password" -AsSecureString
        $passwd2 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
        if($passwd -ne $passwd2){
            Write-Host "Passwords do not match" -ForegroundColor Yellow
        }else{
            $secureString = $passwd | ConvertTo-SecureString -AsPlainText -Force
            $secureString | ConvertFrom-SecureString -key $keyBytes | Out-File $userFile
            Write-Host "`nPassword stored. Use key $keyString to unlock`n"
        }
    }else{
        $secureString = $passwd | ConvertTo-SecureString -AsPlainText -Force
        $secureString | ConvertFrom-SecureString -key $keyBytes | Out-File $userFile
        Write-Host "`nPassword stored. Use key $keyString to unlock`n"
    }
}

function importStoredPassword($vip='helios.cohesity.com', $username='helios', $domain='local', $key, $useApiKey=$false){
    $userFile = $(Join-Path -Path $PSScriptRoot -ChildPath "pw-$vip-$username-$domain.txt")
    $keyBytes = [byte[]]($key -split(''))
    $securePassword = Get-Content $userFile -ErrorAction SilentlyContinue | ConvertTo-SecureString -Key $keyBytes -ErrorAction SilentlyContinue
    $passwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $securePassword ))
    if($passwd){
        $cohesity_api.pwscope = 'user'
        $null = Set-CohesityAPIPassword -vip $vip -username $username -domain $domain -passwd $passwd -useApiKey $useApiKey -helios $helios -quiet
        Remove-Item -Path $userFile -Force
        Write-Host "Password imported successfully" -ForegroundColor Green
    }else{
        Write-Host "Password not accessible!" -ForegroundColor Yellow
    }
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
    if(! $json.split("`n")[1].startsWith('    ')){
        $json = $json.replace('  ', '    ')
    }
    $pscode = ''
    foreach ($line in $json.split("`n")){
        $line = $line.TrimEnd()
        # preserve end of line character
        $finalEntry = $true
        if($line[-1] -eq ','){
            $finalEntry = $false
            $line = $line -replace ".$"
        }        
        # key value delimiter :
        $key, $value = $line.split(':', 2)
        # line is braces only
        $key = $key.Replace('{', '@{').Replace('[','@(').Replace(']', ')')
        if($value){
            $value = $value.trim()
        # value is quoted text
            if($value[0] -eq '"'){
                $line = "$key = $value"
            }
        # value is opening { brace
            elseif('{' -eq $value){
                $value = $value.Replace('{', '@{')
                $line = "$key = $value"
            }
        # value is opening [ list
            elseif('[' -eq $value){
                $value = $value.Replace('[', '@(')
                $line = "$key = $value"                  
            }
        # empty braces
            elseif('{}' -eq $value){
                $value = '@{}'
                $line = "$key = $value"
            }
        # empty list
            elseif('[]' -eq $value){
                $value = '@()'
                $line = "$key = $value"
            }
        # value is opening ( list
            elseif('[' -eq $value){
                $value = $value.Replace('[', '@(')
                $line = "$key = $value"
            }
        # value is a boolean
            elseif($value -eq 'true'){
                $line = "$key = " + '$true'
            }
            elseif($value -eq 'false'){
                $line = "$key = " + '$false'
            }
        # null
            elseif($value -eq 'null'){
                $line = "$key = " + '$null'
            }
            else {
        # value is numeric
                if($value -as [long] -or $value -eq '0'){
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
        if(! $finalEntry){
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
    param(
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
            if($null -ne $prop.Value){
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
}

function getProp{
    param(
        [Parameter(Mandatory = $True)]$obj,
        [Parameter(Mandatory = $True)]$search
    )
    $results = showProps -obj $obj -search $search
    if($results.count -eq 1){
        return $results.split(' ')[-1]
    }else{
        return $null
    }
}


# convert syntax to python
function py($p){
    $parts = $p.split('.',2)
    $py = $parts[0].replace("$","")
    if($parts.Count -gt 1){
        foreach($part in $parts[1].split('.')){
            if($part.Contains('[')){
                $part, $enum = $part.split('[')
                $py = $py + "['$part'][$enum"
            }else{
                $py = $py + "['$part']"
            }
        }
    }
    $py
}


# convert to properly formatted json
function toJson(){
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)]$j
    )
    $out = $j | ConvertTo-Json -Depth 99
    if($out.split("`n")[1].startsWith('    ')){
        $out
    }else{
        $out.replace('  ','    ')
    }
}


# self updater
function cohesityAPIversion([switch]$update){
    if($update){
        $repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
        (Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/cohesity-api/cohesity-api.ps1").content | Out-File -Force cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
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
            $views = api get views?includeInactive=true -version 1
        }else{
            $views = api get views -version 1
        }
    }
    $myViews += $views.views
    $lastResult = $views.lastResult
    while(! $lastResult){
        $lastViewId = $views.views[-1].viewId
        $views = $null
        while(! $views){
            if($includeInactive){
                $views = api get "views?maxViewId=$lastViewId&includeInactive=true" -version 1
            }else{
                $views = api get views?maxViewId=$lastViewId -version 1
            }
        }
        $lastResult = $views.lastResult
        $myViews += $views.views
    }
    return $myViews
}

# . . . . . . . . . . . . . . . . . . .
#  Previous Updates
# . . . . . . . . . . . . . . . . . . .
#
# 2020.11.06 - refactor and simplify
# 2020.11.23 - fix org support, password storage
# 2020.11.26 - added legacy state vars
# 2020.12.04 - added tenant impersonate / switchback
# 2020.12.05 - improved cohesity_api.version and tenant handling
# 2020.12.20 - added JSON compression
#
# . . . . . . . . . . . . . . . . . . .
