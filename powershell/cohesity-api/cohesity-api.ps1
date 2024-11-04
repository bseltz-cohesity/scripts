# . . . . . . . . . . . . . . . . . . .
#  PowerShell Module for Cohesity API
#  Version 2024.10.14 - Brian Seltzer
# . . . . . . . . . . . . . . . . . . .
#
# 2024.01.14 - reenabled legacy access modes
# 2024.01.25 - added support for unicode characters for REST payloads in Windows PowerShell 5.1
# 2024.01.30 - fix - clear header before auth
# 2024-02-18 - fix - toJson function - handle null input
# 2024-02-28 - added support for helios.gov
# 2024-02-29 - added dateToString function
# 2024-05-02 - added quiet switch to fileDownload function
# 2024-05-17 - added support for EntraID (Open ID) authentication
# 2024-06-24 - fixed authentication error for SaaS connectors
# 2024-09-20 - allow posts to read-only helios cluster (for advanced queries)
# 2024-10-14 - fixed date formatting
#
# . . . . . . . . . . . . . . . . . . .

$versionCohesityAPI = '2024.10.14'
$heliosEndpoints = @('helios.cohesity.com', 'helios.gov-cohesity.com')

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
    'header' = @{
        'accept' = 'application/json'; 
        'content-type' = 'application/json'; 
        'User-Agent' = "cohesity-api/$versionCohesityAPI"
    };
    'clusterReadOnly' = $false;
    'heliosConnectedClusters' = $null;
    'pwscope' = 'user';
    'api_version' = $versionCohesityAPI;
    'last_api_error' = 'OK';
    'session' = $null;
    'userAgent' = "cohesity-api/$versionCohesityAPI";
}

$pwfile = $(Join-Path -Path $PSScriptRoot -ChildPath YWRtaW4)
$apilogfile = $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api-debug.log)

# platform detection ==========================================================================

if($PSVersionTable.Platform -ne 'Unix'){
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
    # get call stack
    $caller = ''
    try{
        $callStack = Get-PSCallStack
        $caller = $callStack.Command -join ', '
        $lineNumber = $callStack.ScriptLineNumber -join ', '
    }catch{
        # nothing
    }

    # rotate log
    try{
        $logfile = Get-Item -Path "$apilogfile" -ErrorAction SilentlyContinue
        if($logfile){
            $size = $logfile.Length
            if($size -gt 200000){
                Move-Item -Path "$apilogfile" -Destination "$apilogfile-$(get-date -UFormat '%Y-%m-%d-%H-%M-%S').log"
            }
        }
    }catch{
        # nothing
    }

    # avoid race condition
    $apiErrorDate = Get-Date
    if($Global:lastAPIerror -eq "($caller) line: $lineNumber $logmessage" -and $apiErrorDate -lt $Global:lastAPIerrorDate.AddSeconds(5)){
        Start-Sleep 5
    }
    $Global:lastAPIerror = "($caller) $logmessage"
    $Global:lastAPIerrorDate = $apiErrorDate

    # output message
    "$($apiErrorDate): ($caller) line: $lineNumber $logmessage" | Out-File -FilePath "$apilogfile" -Append -Encoding ascii
}

function reportError($errorObject, [switch]$quiet){
    $thisError = $errorObject.ToString()
    if($thisError.Contains('404 Not Found')){
        $thisError = '404 Not Found'
    }
    $cohesity_api.last_api_error = $thisError
    __writeLog $thisError
    if($cohesity_api.reportApiErrors -and !$quiet){
        if($thisError.contains('"message":')){
            $errorJson = ConvertFrom-Json $thisError
            $errorCode = $errorJson.errorCode
            $errorMessage = $errorJson.message
            if($errorCode -eq 'KStatusUnauthorized' -and $errorMessage -match 'API Key'){
                $errorMessage = 'Authentication failed: Invalid API Key'
            }
            if($errorMessage -match 'Multi-factor Authentication'){
                $errorMessage = 'Authentication failed: MFA Code Required'
            }
            $cohesity_api.last_api_error = $errorMessage
            Write-Host $errorMessage -foregroundcolor yellow
        }else{
            Write-Host $thisError -foregroundcolor yellow
        }
    }
}

# authentication functions ========================================================================
function apiauth($vip='helios.cohesity.com',
                 $username = 'helios',
                 $passwd = $null,
                 $password = $null,
                 $newPassword = $null,
                 $domain = 'local',
                 $tenant = $null,
                 $regionid = $null,
                 $mfaType = 'Totp',
                 [string] $mfaCode = $null,
                 [switch] $emailMfaCode,
                 [switch] $helios,
                 [switch] $noDomain,
                 [switch] $quiet,
                 [switch] $noprompt,
                 [switch] $updatePassword,
                 [switch] $useApiKey,
                 [boolean] $apiKeyAuthentication = $false,
                 [boolean] $heliosAuthentication = $false,
                 [boolean] $sendMfaCode = $false,
                 [boolean] $noPromptForPassword = $false,
                 [Int]$timeout = 300,
                 [switch] $EntraId,
                 [string] $clientId = $null,
                 [string] $directoryId = $null,
                 [string] $scope = 'openid profile',
                 [boolean] $entraIdAuthentication = $false){
    apidrop -quiet
    if($entraIdAuthentication -eq $True){
        $EntraId = $True
    }
    if($apiKeyAuthentication -eq $True){
        $useApiKey = $True
    }
    if($heliosAuthentication -eq $True){
        $helios = $True
    }
    if($sendMfaCode -eq $True){
        $emailMfaCode = $True
    }
    if($noPromptForPassword -eq $True){
        $noprompt = $True
    }
    # parse domain\username or username@domain
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    if($password){ 
        $passwd = $password
    }
    $setpasswd = $null
    if($passwd){
        $setpasswd = $passwd
    }
    # update password
    if($updatePassword -or $clearPassword){
        $passwd = Set-CohesityAPIPassword -vip $vip -username $username -domain $domain -passwd $passwd -quiet -useApiKey $useApiKey -helios $helios
    }
    # get stored password
    if(!$passwd){
        $passwd = Get-CohesityAPIPassword -vip $vip -username $username -domain $domain -useApiKey $useApiKey -helios $helios
        if(!$passwd -and !$noprompt -and $noPromptForPassword -ne $True){
            # prompt for password and store
            $passwd = Set-CohesityAPIPassword -vip $vip -username $username -domain $domain -quiet -useApiKey $useApiKey -helios $helios -EntraId $EntraId
        }
        if(!$passwd){
            # report no password
            $cohesity_api.last_api_error = "No password provided for $domain\$username at $vip"
            Write-Host "No password provided for $domain\$username at $vip" -ForegroundColor Yellow
            __writeLog "No password provided for $domain\$username at $vip"
            apidrop -quiet
            return $null
        }
    }

    $cohesity_api.apiRoot = 'https://' + $vip + '/irisservices/api/v1'
    $cohesity_api.apiRootv2 = 'https://' + $vip + '/v2/'
    $cohesity_api.apiRootmcm = "https://$vip/mcm/"
    $cohesity_api.apiRootmcmV2 = "https://$vip/v2/mcm/"
    $cohesity_api.apiRootReportingV2 = "https://$vip/heliosreporting/api/v1/public/"

    if($regionid){
        $cohesity_api.header['regionid'] = $regionid
    }
    # Entra ID (OIDC) authentication
    if($EntraId -and ($vip -in $heliosEndpoints)){
        $header = $cohesity_api.header.Clone()
        if(!$directoryId){
            $directoryId = Get-CohesityAPIPassword -vip $vip -username $username -domain $domain -directoryId $True
            if(!$directoryId){
                $directoryId = Set-CohesityAPIPassword -vip $vip -username $username -domain $domain -directoryId $True -quiet
            }
        }
        if(!$clientId){
            $clientId = Get-CohesityAPIPassword -vip $vip -username $username -domain $domain -clientId $True
            if(!$clientId){
                $clientId = Set-CohesityAPIPassword -vip $vip -username $username -domain $domain -clientId $True -quiet
            }
        }
        # Write-Host "clientId: $clientId"
        # Write-Host "directoryId: $directoryId"
        # Write-Host "scope: $scope"
        # Write-Host "passwd: $passwd"
        # Write-Host "username: $username"
        if($clientId -and $directoryId -and $scope){
            $token = ProcessOidcToken -username $username -password $passwd -client_id $clientId -tenant_id $directoryId -scope $scope
            # Write-Host $token
            if($token){
                $header['X-OPEN-ID-AUTHZ-TOKEN'] = $token
                $cohesity_api.authorized = $true
                try{
                    $URL = "https://$vip/mcm/clusters/connectionStatus"
                    if($PSVersionTable.PSEdition -eq 'Core'){
                        $heliosAllClusters = Invoke-RestMethod -Method Get -Uri $URL -Header $header -TimeoutSec $timeout -UserAgent $cohesity_api.userAgent -SslProtocol Tls12 -SkipCertificateCheck -SessionVariable session
                    }else{
                        $heliosAllClusters = Invoke-RestMethod -Method Get -Uri $URL -Header $header -TimeoutSec $timeout -UserAgent $cohesity_api.userAgent -SessionVariable session
                    }
                    $cohesity_api.session = $session
                    $Global:USING_HELIOS = $true
                    $cohesity_api.heliosConnectedClusters = $heliosAllClusters | Where-Object {$_.connectedToCluster -eq $true}
                    if($setpasswd){
                        $passwd = Set-CohesityAPIPassword -vip $vip -username $username -domain $domain -passwd $passwd -quiet -useApiKey $useApiKey -helios $helios
                    }
                    if(!$quiet){ Write-Host "Connected!" -foregroundcolor green }
                }catch{
                    if($quiet){
                        reportError $_ -quiet
                    }else{
                        reportError $_ 
                    }
                    apidrop -quiet
                }
            }
        }else{
            Write-Host "Missing OIDC parameters" -ForegroundColor Yellow
        }
        return $null
    }
    
    # API Key authentication
    if($useApiKey -or $helios -or ($vip -in $heliosEndpoints)){
        $header = $cohesity_api.header.Clone()
        $header['apiKey'] = $passwd
        $cohesity_api.authorized = $true
        # validate cluster API key authorization
        if($useApiKey -and (($vip -notin $heliosEndpoints) -and $helios -ne $True)){
            try{
                $URL = "https://$vip/irisservices/api/v1/public/sessionUser/preferences"
                if($PSVersionTable.PSEdition -eq 'Core'){
                    $cluster = Invoke-RestMethod -Method Get -Uri $URL -Header $header -UserAgent $cohesity_api.userAgent -SslProtocol Tls12 -TimeoutSec $timeout -SkipCertificateCheck -SessionVariable session
                }else{
                    $cluster = Invoke-RestMethod -Method Get -Uri $URL -Header $header -UserAgent $cohesity_api.userAgent -TimeoutSec $timeout -SessionVariable session
                }
                $cohesity_api.session = $session
                if($setpasswd){
                    $passwd = Set-CohesityAPIPassword -vip $vip -username $username -domain $domain -passwd $passwd -quiet -useApiKey $useApiKey -helios $helios
                }
                if(!$quiet){ Write-Host "Connected!" -foregroundcolor green }
            }catch{
                if($quiet){
                    reportError $_ -quiet
                }else{
                    reportError $_ 
                }
                apidrop -quiet
                if(!$noprompt -and $cohesity_api.last_api_error -eq "Authentication failed: Invalid API Key"){
                    apiauth -vip $vip -username $username -domain $domain -useApiKey -updatePassword
                }
            }
        }
        # validate helios/mcm authorization
        if($vip -in $heliosEndpoints -or $helios){
            try{
                $URL = "https://$vip/mcm/clusters/connectionStatus"
                if($PSVersionTable.PSEdition -eq 'Core'){
                    $heliosAllClusters = Invoke-RestMethod -Method Get -Uri $URL -Header $header -TimeoutSec $timeout -UserAgent $cohesity_api.userAgent -SslProtocol Tls12 -SkipCertificateCheck -SessionVariable session
                }else{
                    $heliosAllClusters = Invoke-RestMethod -Method Get -Uri $URL -Header $header -TimeoutSec $timeout -UserAgent $cohesity_api.userAgent -SessionVariable session
                }
                $cohesity_api.session = $session
                $Global:USING_HELIOS = $true
                $cohesity_api.heliosConnectedClusters = $heliosAllClusters | Where-Object {$_.connectedToCluster -eq $true}
                if($setpasswd){
                    $passwd = Set-CohesityAPIPassword -vip $vip -username $username -domain $domain -passwd $passwd -quiet -useApiKey $useApiKey -helios $helios
                }
                if(!$quiet){ Write-Host "Connected!" -foregroundcolor green }
            }catch{
                if($quiet){
                    reportError $_ -quiet
                }else{
                    reportError $_ 
                }
                apidrop -quiet
                if(!$noprompt -and $cohesity_api.last_api_error -eq "Authentication failed: Unauthorized access."){
                    apiauth -vip $vip -username $username -domain $domain -updatePassword
                }
            }
        }
    }else{
        # username/password authentication
        $Global:USING_HELIOS = $false
        $Global:USING_HELIOS | Out-Null

        $body = ConvertTo-Json @{
            'domain' = $domain;
            'username' = $username;
            'password' = "$passwd";
        }

        if($noDomain){
            $body = ConvertTo-Json @{
                'username' = $username;
                'password' = $passwd;
            }
        }

        try {
            $url = 'https://' + $vip + '/login'
            if($PSVersionTable.PSEdition -eq 'Core'){
                $user = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -Body $body -SkipCertificateCheck -UserAgent $cohesity_api.userAgent -TimeoutSec $timeout -SslProtocol Tls12 -SessionVariable session
            }else{
                $user = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -Body $body -UserAgent $cohesity_api.userAgent -TimeoutSec $timeout -SessionVariable session -ContentType "application/json; charset=utf-8"
            }
            $cohesity_api.session = $session
            # check force password change
            if(! $noDomain){
                try{
                    $changePassword = $false
                    if($user.user.forcePasswordChange -eq $True){
                        if($newPassword){
                            $confirmPassword = $newPassword
                            $changePassword = $True
                        }else{
                            $newPassword = '1'
                            $confirmPassword = '2'
                            Write-Host "Password is expired" -ForegroundColor Yellow
                        }
                        if(!$noprompt){
                            while($newPassword -cne $confirmPassword){
                                $secureNewPassword = Read-Host -Prompt "  Enter new password" -AsSecureString
                                $secureConfirmPassword = Read-Host -Prompt "Confirm new password" -AsSecureString
                                $newPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureNewPassword ))
                                $confirmPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureConfirmPassword ))
                                if($newPassword -cne $confirmPassword){
                                    Write-Host "Passwords do not match" -ForegroundColor Yellow
                                }
                            }
                            $changePassword = $True
                        }
                    }else{
                        if($newPassword){
                            $changePassword = $True
                        }
                    }
                    if($changePassword -eq $True){
                        $user.user | Add-Member -MemberType NoteProperty -Name 'currentPassword' -Value $passwd
                        $user.user | Add-Member -MemberType NoteProperty -Name 'password' -Value $newPassword
    
                        $URL = "https://$vip/irisservices/api/v1/public/users"
                        if($PSVersionTable.PSEdition -eq 'Core'){
                            $userupdate = Invoke-RestMethod -Method Put -Uri $URL -Header $cohesity_api.header -Body ($user.user | ConvertTo-Json) -SkipCertificateCheck -UserAgent $cohesity_api.userAgent -TimeoutSec $timeout -SslProtocol Tls12 -WebSession $session
                        }else{
                            $userupdate = Invoke-RestMethod -Method Put -Uri $URL -Header $cohesity_api.header -Body ($user.user | ConvertTo-Json) -WebSession $session -UserAgent $cohesity_api.userAgent -TimeoutSec $timeout -ContentType "application/json; charset=utf-8"
                        }
    
                        $body = ConvertTo-Json @{
                            'domain' = $domain;
                            'username' = $username;
                            'password' = $newPassword;
                        }
    
                        $url = 'https://' + $vip + '/login'
                        if($PSVersionTable.PSEdition -eq 'Core'){
                            $user = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -Body $body -SkipCertificateCheck -UserAgent $cohesity_api.userAgent -TimeoutSec $timeout -SslProtocol Tls12 -SessionVariable session
                        }else{
                            $user = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -Body $body -UserAgent $cohesity_api.userAgent -TimeoutSec $timeout -SessionVariable session -ContentType "application/json; charset=utf-8"
                        }
                        $cohesity_api.session = $session
                        $passwd = Set-CohesityAPIPassword -vip $vip -username $username -passwd $newPassword -quiet
                    }
                }catch{
                    if($quiet){
                        reportError $_ -quiet
                    }else{
                        reportError $_ 
                    }
                    apidrop -quiet
                    return $null
                }
                # multi-factor authentication
                if($mfaCode -or $emailMfaCode){
                    $otpType = "Totp"
                    if($emailMfaCode){
                        $url = "https://$vip/v2/send-email-otp"
                        if($PSVersionTable.PSEdition -eq 'Core'){
                            $sent = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -TimeoutSec $timeout -UserAgent $cohesity_api.userAgent -SslProtocol Tls12 -WebSession $cohesity_api.session -SkipCertificateCheck
                        }else{
                            $sent = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -TimeoutSec $timeout -UserAgent $cohesity_api.userAgent -WebSession $cohesity_api.session
                        }
                        $mfaCode = Read-Host -Prompt 'Enter MFA Code'
                        $otpType = "Email"
                    }
                    try{
                        $mfaCheck = @{
                            "otpCode" = "$mfaCode";
                            "otpType" = "$otpType"
                        }
                        $url = "https://$vip/irisservices/api/v1/public/verify-otp"
                        if($PSVersionTable.PSEdition -eq 'Core'){
                            $verify = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -Body ($mfaCheck | ConvertTo-Json) -TimeoutSec $timeout -UserAgent $cohesity_api.userAgent -SslProtocol Tls12 -WebSession $cohesity_api.session -SkipCertificateCheck
                        }else{
                            $verify = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -Body ($mfaCheck | ConvertTo-Json) -TimeoutSec $timeout -UserAgent $cohesity_api.userAgent -WebSession $cohesity_api.session
                        }
                    }catch{
                        if($quiet){
                            reportError $_ -quiet
                        }else{
                            reportError $_ 
                        }
                        apidrop -quiet
                        return $null
                    }
                }
                # validate authorization
                $URL = "https://$vip/irisservices/api/v1/public/sessionUser/preferences"
                if($PSVersionTable.PSEdition -eq 'Core'){
                    $cluster = Invoke-RestMethod -Method Get -Uri $URL -Header $cohesity_api.header -TimeoutSec $timeout -UserAgent $cohesity_api.userAgent -SslProtocol Tls12 -SkipCertificateCheck -WebSession $cohesity_api.session
                }else{
                    $cluster = Invoke-RestMethod -Method Get -Uri $URL -Header $cohesity_api.header -TimeoutSec $timeout -UserAgent $cohesity_api.userAgent -WebSession $cohesity_api.session
                }
            }

            # set state connected
            $cohesity_api.authorized = $true
            $cohesity_api.clusterReadOnly = $false
            if($setpasswd){
                $passwd = Set-CohesityAPIPassword -vip $vip -username $username -domain $domain -passwd $passwd -quiet -useApiKey $useApiKey -helios $helios
            }
            if(!$quiet){ Write-Host "Connected!" -foregroundcolor green }
        }catch{
            $thisError = $_
            if($thisError -match 'User does not have the privilege to access UI' -or $thisError -match "KInvalidError"){
                $url = $cohesity_api.apiRoot + '/public/accessTokens'
                try {
                    if($emailMfaCode){
                        Write-Host "scripted MFA via email is disabled, please use -mfaCode xxxxxx" -ForegroundColor Yellow
                        apidrop -quiet
                        break
                    }
                    # authenticate
                    if($PSVersionTable.PSEdition -eq 'Core'){
                        $auth = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -Body $body -SkipCertificateCheck -UserAgent $userAgent -TimeoutSec $timeout -SslProtocol Tls12 -WebSession $cohesity_api.session
                    }else{
                        $auth = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -Body $body -UserAgent $userAgent -TimeoutSec $timeout -WebSession $cohesity_api.session -ContentType "application/json; charset=utf-8"
                    }
                    $cohesity_api.session = $session
                    $cohesity_api.authorized = $true
                    $cohesity_api.clusterReadOnly = $false
                    if(!$quiet){ Write-Host "Connected!" -foregroundcolor green }
                }catch{
                    $cohesity_api.last_api_error = $_.ToString()
                    $thisError = $_
                    # try v2 session auth
                    if($thisError.ToString().contains('"message":')){
                        $message = (ConvertFrom-Json $thisError.ToString()).message
                        $cohesity_api.last_api_error = $message
                        if($message -eq 'Access denied'){
                            try{
                                $url = $cohesity_api.apiRootv2 + 'users/sessions'
                                $body = ConvertTo-Json @{
                                    'domain' = $domain;
                                    'username' = $username;
                                    'password' = $passwd;
                                    'otpType' = $mfaType.ToLower();
                                    'otpCode' = $mfaCode
                                }
                                # authenticate
                                if($PSVersionTable.PSEdition -eq 'Core'){
                                    $auth = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -Body $body -SkipCertificateCheck -UserAgent $userAgent -TimeoutSec $timeout -SslProtocol Tls12 -WebSession $cohesity_api.session
                                }else{
                                    $auth = Invoke-RestMethod -Method Post -Uri $url -header $cohesity_api.header -Body $body -UserAgent $userAgent -TimeoutSec $timeout -WebSession $cohesity_api.session -ContentType "application/json; charset=utf-8"
                                }
                                $cohesity_api.session = $session
                                $cohesity_api.authorized = $true
                                $cohesity_api.clusterReadOnly = $false
                                if(!$quiet){
                                    Write-Host "Connected!" -foregroundcolor green
                                }
                            }catch{
                                $cohesity_api.last_api_error = "user session authentication failed"
                                apidrop -quiet
                                __writeLog $thisError.ToString()
                                if($cohesity_api.reportApiErrors){
                                    if($thisError.ToString().contains('"message":')){
                                        $message = (ConvertFrom-Json $_.ToString()).message
                                        Write-Host $message -foregroundcolor yellow
                                        if($message -match 'Invalid Username or Password'){
                                            if(!$noprompt){
                                                apiauth -vip $vip -username $username -domain $domain -mfaCode $mfaCode -tenant $tenant -updatePassword
                                            }
                                        }
                                    }else{
                                        Write-Host $thisError.ToString() -foregroundcolor yellow
                                    }
                                }
                                return $null
                            }
                        }else{
                            # report authentication error
                            apidrop -quiet
                            __writeLog $thisError.ToString()
                            $message = (ConvertFrom-Json $_.ToString()).message
                            if($cohesity_api.reportApiErrors){
                                Write-Host $message -foregroundcolor yellow
                                $cohesity_api.last_api_error = $message
                                if($message -match 'Invalid Username or Password'){
                                    if(!$noprompt){
                                        apiauth -vip $vip -username $username -domain $domain -mfaCode $mfaCode -tenant $tenant -updatePassword
                                    }
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
                                    if(!$noprompt){
                                        apiauth -vip $vip -username $username -domain $domain -mfaCode $mfaCode -tenant $tenant -updatePassword
                                    }
                                }
                            }else{
                                if($thisError.ToString() -match '404 Not Found'){
                                    Write-Host 'connection refused'
                                    $cohesity_api.last_api_error = 'connection refused'
                                    apidrop -quiet
                                }else{
                                    Write-Host $thisError.ToString() -foregroundcolor yellow
                                }
                            }
                        }
                    }
                }
                # ============================================================================================
                return $null
            }
            if($quiet){
                reportError $_ -quiet
            }else{
                reportError $_ 
            }
            apidrop -quiet
            if($thisError.ToString().contains('"message":')){
                $message = (ConvertFrom-Json $_.ToString()).message
                if($message -match 'Invalid Username or Password'){
                    if(!$noprompt){
                        apiauth -vip $vip -username $username -domain $domain -mfaCode $mfaCode -tenant $tenant -updatePassword
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
            $cohesity_api.clusterReadOnly = (api get /mcm/config).mcmReadOnly
            return "Connected to $clusterName"
        }else{
            Write-Host "Cluster $clusterName not connected to Helios" -ForegroundColor Yellow
            $cohesity_api.header.remove('accessClusterId')
            $cohesity_api.header.remove('clusterId')
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
    $cohesity_api.header = @{
        'accept' = 'application/json'; 
        'content-type' = 'application/json'; 
        'User-Agent' = "cohesity-api/$versionCohesityAPI"
    }
    $cohesity_api.pwscope = 'user'
    $cohesity_api.authorized = $false
    $cohesity_api.apiRoot = ''
    $cohesity_api.apiRootv2 = ''
    $cohesity_api.clusterReadOnly = $false
    $cohesity_api.heliosConnectedClusters = $null
    $cohesity_api.session = $null
    if(!$quiet){ Write-Host "Disonnected!" -foregroundcolor green }
    $Global:AUTHORIZED = $cohesity_api.authorized
    $Global:AUTHORIZED | Out-Null
    $Global:USING_HELIOS = $false
    $Global:USING_HELIOS | Out-Null
}

function impersonate($tenant){
    if($cohesity_api.authorized){ 
        $thisTenant = api get tenants | Where-Object {$_.name -eq $tenant}
        if($thisTenant){
            $cohesity_api.header['x-impersonate-tenant-id'] = $thisTenant.tenantId
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
        $script:cohesity_api = $context.Clone()
    }else{
        Write-Host "Invalid context" -ForegroundColor Yellow
    }
}

function accessCluster($remoteClusterName=$null){
    if($cohesity_api.heliosConnectedClusters -eq $null){
        if($remoteClusterName -eq $null -or $remoteClusterName -eq '-'){
            $cohesity_api.header.Remove('clusterId')        
        }else{
            $remoteClusters = api get remoteClusters | Where-Object purposeRemoteAccess -eq $True
            if($remoteClusterName -in $remoteClusters.name){
                $remoteCluster = $remoteClusters | Where-Object name -eq $remoteClusterName
                if($remoteCluster){
                    $cohesity_api.header['clusterId'] = $remoteCluster.clusterId
                    Write-Host "Connecting to $($remoteCluster.name)"              
                }
            }else{
                Write-Host "$remoteClusterName not found" -ForegroundColor Yellow
            }
        }
    }else{
        heliosCluster $remoteClusterName
    }
}

function copySessionCookie($ip){
    if($cohesity_api.session){
        $cookies = $cohesity_api.session.Cookies.GetCookies($cohesity_api.apiRoot)
        $cookie = New-Object System.Net.Cookie
        $cookie.Name = $cookies[0].Name
        $cookie.Value = $cookies[0].Value
        $cookie.Domain = $ip
        $cohesity_api.session.Cookies.Add($cookie)
    }
}

# api call function ==============================================================================

$methods = 'get', 'post', 'put', 'delete', 'patch'
function api($method, 
             $uri, 
             $data,
             $region,
             [switch]$v2,
             [switch]$mcm,
             [switch]$mcmv2,
             [switch]$reportingV2,
             [switch]$quiet,
             [Int]$timeout=300){

    if($method -eq 'get'){
        $body = $null
        $data = $null
    }

    $header = $cohesity_api.header.Clone()
    if($region){
        $header['regionid'] = $region
    }

    if(-not $cohesity_api.authorized){
        $cohesity_api.last_api_error = 'not authorized'
        if($cohesity_api.reportApiErrors){
            Write-Host 'Not authenticated to a cohesity cluster' -foregroundcolor yellow
            return $null
        }
    }else{
        if($method -notin $methods){
            $cohesity_api.last_api_error = "invalid api method: $method"
            if($cohesity_api.reportApiErrors){
                Write-Host "invalid api method: $method" -foregroundcolor yellow
            }
            return $null
        }
        
        if($uri.StartsWith("https://")){
            $url = $uri
        }elseif($v2){
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
                    $result = Invoke-RestMethod -Method $method -Uri $url -Body $body -header $header -SkipCertificateCheck -UserAgent $cohesity_api.userAgent -TimeoutSec $timeout -SslProtocol Tls12 -WebSession $cohesity_api.session
                }else{
                    $result = Invoke-RestMethod -Method $method -Uri $url -header $header -SkipCertificateCheck -UserAgent $cohesity_api.userAgent -TimeoutSec $timeout -SslProtocol Tls12 -WebSession $cohesity_api.session
                }
            }else{
                if($body){
                    $result = Invoke-RestMethod -Method $method -Uri $url -Body $body -header $header -UserAgent $cohesity_api.userAgent -TimeoutSec $timeout -WebSession $cohesity_api.session -ContentType "application/json; charset=utf-8"
                }else{
                    $result = Invoke-RestMethod -Method $method -Uri $url -header $header -UserAgent $cohesity_api.userAgent -TimeoutSec $timeout -WebSession $cohesity_api.session -ContentType "application/json; charset=utf-8"
                }
            }
            $cohesity_api.last_api_error = 'OK'
            return $result
        }catch{
            if($quiet){
                reportError $_ -quiet
            }else{
                reportError $_ 
            }
        }
    }
}

# file download function ========================================================================

function fileDownload($uri, $fileName, [switch]$v2, [switch]$quiet){
    if(-not $cohesity_api.authorized){ Write-Host 'Please use apiauth to connect to a cohesity cluster' -foregroundcolor yellow; return $null }
    try {
        if($uri -match "://"){
            $url = $uri
        }elseif($v2){
            $url = $cohesity_api.apiRootv2 + $uri
        }else{
            if($uri[0] -ne '/'){ $uri = '/public/' + $uri}
            $url = $cohesity_api.apiRoot + $uri
        }
        if($fileName -notmatch '\\'){
            $fileName = $(Join-Path -Path $PSScriptRoot -ChildPath $fileName)
        }
        if($PSVersionTable.PSEdition -eq 'Core'){
            Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $fileName -Header $cohesity_api.header -WebSession $cohesity_api.session -UserAgent $cohesity_api.userAgent -SslProtocol Tls12 -SkipCertificateCheck
        }else{
            Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $fileName -Header $cohesity_api.header -WebSession $cohesity_api.session -UserAgent $cohesity_api.userAgent
        }
        $cohesity_api.last_api_error = 'OK'
    }catch{
        if($quiet){
            reportError $_ -quiet
        }else{
            reportError $_ 
        }          
    }
}

# file upload function ========================================================================

function fileUpload($uri, $fileName, [switch]$v2){
    if(-not $cohesity_api.authorized){ Write-Host 'Please use apiauth to connect to a cohesity cluster' -foregroundcolor yellow; return $null }
    try {
        if($uri -match "://"){
            $url = $uri
        }elseif($v2){
            $url = $cohesity_api.apiRootv2 + $uri
        }else{
            if($uri[0] -ne '/'){ $uri = '/public/' + $uri}
            $url = $cohesity_api.apiRoot + $uri
        }
        if($fileName -notmatch '\\' -and $fileName -notmatch '/'){
            $fileName = $(Join-Path -Path $PSScriptRoot -ChildPath $fileName)
        }
        if($PSVersionTable.PSEdition -eq 'Core'){
            $result = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $url -InFile $fileName -Header $cohesity_api.header -WebSession $cohesity_api.session -UserAgent $cohesity_api.userAgent -SslProtocol Tls12 -SkipCertificateCheck
        }else{
            $result = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $url -InFile $fileName -Header $cohesity_api.header -WebSession $cohesity_api.session -UserAgent $cohesity_api.userAgent
        }
        $cohesity_api.last_api_error = 'OK'
        return $result
    }catch{
        reportError $_
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
    try{
        $unixTime=$usecs/1000000
        $origin = ([datetime]'1970-01-01 00:00:00')
        if($format){
            return ($origin.AddSeconds($unixTime).ToLocalTime().ToString($format) -replace [char]8239, ' ')
        }else{
            return ($origin.AddSeconds($unixTime).ToLocalTime()) # .ToString() -replace [char]8239, ' ')
        }
    }catch{
        Write-Host "usecsToDate: incorrect input type ($($usecs.GetType().name)) must be Int64" -ForegroundColor Yellow
        return $null
    }
}

function dateToUsecs($datestring=(Get-Date)){
    if($datestring -isnot [datetime]){ $datestring = [datetime] $datestring }
    $usecs = [int64](($datestring.ToUniversalTime())-([datetime]"1970-01-01 00:00:00")).TotalSeconds*1000000
    $usecs
}

function dateToString($dt, $format='yyyy-MM-dd hh:mm'){
    return ($dt.ToString($format) -replace [char]8239, ' ')
}

# password functions ==============================================================================

function Get-CohesityAPIPassword($vip='helios.cohesity.com', $username='helios', $domain='local', $useApiKey=$false, $helios=$false, $directoryId=$false, $clientId=$false){
    if($directoryId){
        $useApiKey = 'directoryId'
    }elseif($clientId){
        $useApiKey = 'clientId'
    }elseif($helios -eq $True -or $vip -in $heliosEndpoints){
        $useApiKey = $false
    }
    # parse domain\username or username@domain
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    if($domain -ne 'local' -and $helios -eq $false -and $vip -notin $heliosEndpoints -and $useApiKey -eq $false){
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
        if($v -eq $vip -and $d -eq $domain -and $u -eq $username -and $i -eq $useApiKey){
            $cohesity_api.pwscope = 'file'
            $passwd = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($cpwd))
            return $passwd
        }
    }
    return $null
}

function Clear-CohesityAPIPassword($vip='helios.cohesity.com', $username='helios', $domain='local', [switch]$quiet, $useApiKey=$false, $helios=$false, $directoryId=$false, $clientId=$false){
    if($directoryId){
        $useApiKey = 'directoryId'
    }elseif($clientId){
        $useApiKey = 'clientId'
    }elseif($helios -eq $True -or $vip -in $heliosEndpoints){
        $useApiKey = $false
    }
    # parse domain\username or username@domain
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    if($domain -ne 'local' -and !$helios -and $vip -notin $heliosEndpoints -and $useApiKey -eq $false){
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
    try{
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
        if($updatedContent -eq ''){
            Remove-Item -FilePath $pwfile -ErrorAction SilentlyContinue
        }else{
            $updatedContent | out-file -FilePath $pwfile
        }
    }catch{

    }
}

function Set-CohesityAPIPassword($vip='helios.cohesity.com', $username='helios', $domain='local', $passwd=$null, [switch]$quiet, $useApiKey=$false, $helios=$false, $directoryId=$false, $clientId=$false, $EntraId=$false){

    if($directoryId){
        $useApiKey = 'directoryId'
    }elseif($clientId){
        $useApiKey = 'clientId'
    }elseif($EntraId){
        $useApiKey = $false
    }elseif($helios -eq $True -or $vip -in $heliosEndpoints){
        $useApiKey = $false
    }
    # parse domain\username or username@domain
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    $originalVip = $vip
    $originalUsername = $username

    if($domain -ne 'local' -and !$helios -and $vip -notin $heliosEndpoints -and $useApiKey -eq $false){
        $originalUsername = "$domain\$username"
        $vip = '--'  # wildcard vip for AD accounts
    }
    if(!$passwd){
        __writeLog "Prompting for Password"
        if($EntraId){
            $secureString = Read-Host -Prompt "Enter password for $originalUsername at $originalVip" -AsSecureString
        }elseif($directoryId){
            $secureString = Read-Host -Prompt "Enter Directory ID for $originalUsername" -AsSecureString
        }elseif($clientId){
            $secureString = Read-Host -Prompt "Enter Client ID for $originalUsername" -AsSecureString
        }elseif($useApiKey -or $helios -or $vip -in $heliosEndpoints){
            $secureString = Read-Host -Prompt "Enter API key for $originalUsername at $originalVip" -AsSecureString
        }else{
            $secureString = Read-Host -Prompt "Enter password for $originalUsername at $originalVip" -AsSecureString
        }
        $passwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
    }
    $opwd = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($passwd))

    Clear-CohesityAPIPassword -vip $vip -username $username -domain $domain -useApiKey $useApiKey -helios $helios

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
                Set-ItemProperty -Path "$registryPath" -Name "$keyName" -Value "$encryptedPasswordText" -Force
            }
        }
    }else{
        try{
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
        }catch{

        }
    }

    if(!$quiet){ Write-Host "Password stored!" -ForegroundColor Green }
    return $passwd
}

function storePasswordInFile($vip='helios.cohesity.com', $username='helios', $domain='local', $passwd=$null, [switch]$useApiKey){
    $cohesity_api.pwscope = 'file'
    $null = Set-CohesityAPIPassword -vip $vip -username $username -domain $domain -passwd $passwd -useApiKey $useApiKey -helios $helios
    $cohesity_api.pwscope = 'user'
}

function storePasswordForUser($vip='helios.cohesity.com', $username='helios', $domain='local', $passwd=$null){
    if($username.Contains('\')){
        $domain, $username = $username.Split('\')
    }
    $userFile = $(Join-Path -Path $PSScriptRoot -ChildPath "pw-$vip-$username-$domain.txt")
    $keyString = (Get-Random -Minimum 10000000000000 -Maximum 99999999999999).ToString()
    $keyBytes = [byte[]]($keyString -split(''))
    if($null -eq $passwd -or $passwd -eq ''){
        $secureString = Read-Host -Prompt "Enter password or API key for $username at $vip" -AsSecureString
        $passwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
        $secureString = Read-Host -Prompt "Confirm password or API key for $username at $vip" -AsSecureString
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
    if(Test-Path -Path $userFile){
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
    }else{
        Write-Host "Password not accessible!" -ForegroundColor Yellow
    }
}

function ProcessOidcToken ([string]$username, [string]$password, [string]$client_id, [string]$tenant_id, [string]$scope = 'openid profile'){
    $tokenreturn=$null
    $tokenreturn=Invoke-RestConOIDCAzure -username ($username) -pwdx ($password) -cidx ($client_id) -tidx ($tenant_id) -scope ($scope)    
    If($tokenreturn.Exception) {
        return Write-Host "Error Connection: $tokenreturn" -ForegroundColor red
    }else{
        return $tokenreturn
    }
}

function Invoke-RestConOIDCAzure  {
    param ( [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$username,
            [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()] $pwdx,
            [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$cidx,
            [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$tidx,
            [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$scope)    
    $callazure=$null
    if(($pwdx.GetType().name) -eq 'SecureString'){ 
        [string]$psswdx=(New-Object PSCredential 0, $pwdx).GetNetworkCredential().Password
    }else{
        $psswdx=$pwdx
    }    
    $Azbody = @{
        'grant_type'    = 'password';
        'client_id'     = $cidx;
        'scope'         = $scope;
        'username'      = $username;
        'password'      = $psswdx;
    }
    $AzureURL="https://login.microsoftonline.com/$tidx/oauth2/v2.0/token"
    $azuhdr = @{
        'content-type' = "application/x-www-form-urlencoded;charset=utf-8";
        'Accept'= "application/json"
    }
    try{
        $callazure = Invoke-RestMethod -Method POST -Uri $AzureURL -Body $Azbody -Headers $azuhdr -TimeoutSec 100
    }catch{
        $myerrorz="ERROR $(get-date)";
        $excepx=($myerrorz, $_)
        return $excepx
    }
    $OidcToken=$callazure.id_token
    return $OidcToken
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
        if($object.$name.GetType().Name -eq 'HashTable'){
            $object.$name = $object.$name | ConvertTo-Json -Depth 99 | ConvertFrom-Json
        }
    }else{
        $object.$name = $value
    }
}

# delete a property
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
    process{
        if($_){
            $out = $_ | ConvertTo-Json -Depth 99
            if($out.split("`n")[1].startsWith('    ')){
                $out
            }else{
                $out.replace('  ','    ')
            }
        }else{
            "null"
        }
    }
}

# self updater
function cohesityAPIversion([switch]$update){
    if($update){
        $repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
        if($PSVersionTable.PSEdition -eq 'Core'){
            (Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/cohesity-api/cohesity-api.ps1" -SkipCertificateCheck).content | Out-File -Force cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
        }else{
            (Invoke-WebRequest -UseBasicParsing -Uri "$repoURL/cohesity-api/cohesity-api.ps1").content | Out-File -Force cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
        }
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
# 2021.02.10 - fixed empty body issue
# 2021.03.26 - added apiKey unique password storage
# 2021.08.16 - revamped passwd storage, auto prompt for invalid password
# 2021.09.23 - added support for DMaaS, Helios Reporting V2
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
# 2022.02.17 - disabled pwfile autodeletion
# 2022.04.12 - updated importStoredPassword error handling and case insensitive api method
# 2022.04.14 - fixed store and import - support domain\username convention
# 2022.05.16 - fixed mfa for v2 user/session authentication
# 2022.08.02 - added promptForPassword as boolean
# 2022.09.07 - clear state cache before new logon, fixed bad password handling
# 2022.09.09 - set timeout to 300 secs, store password if stored on the command line
# 2022.09.11 - added log file rotate and added call stack to log entries 
# 2022.09.13 - added $cohesity_api.last_api_error
# 2022.09.19 - fixed log encoding
# 2022.09.22 - fixed 404 error output format
# 2022.09.27 - fixed error log not found error
# 2023.02.10 - added -region to api function (for DMaaS)
# 2023.03.22 - added accessCluster function
# 2023.04.04 - exit 1 on old PowerShell version
# 2023.04.30 - disable email MFA and add timeout parameter
# 2023.05.18 - fixed setApiProperty function
# 2023.05.23 - fixed setContext
# 2023.06.01 - fixed setApiProperty function
# 2023.07.12 - ignore write failure to pwfile
# 2023.08.15 - enforce Tls12
# 2023.08.28 - add offending line number to cohesity-api-log
# 2023.09.22 - added fileUpload function
# 2023.09.24 - web session authentication, added support for password reset. email MFA
# 2023.10.03 - fix cosmetic error 'An item with the same key has already been added. Key: content-type'
# 2023.10.09 - clarify password / API key prompts
# 2023.10.11 - removed demand minimim powershell version, to support Start-Job
# 2023.10.13 - fixed password prompt for AD user
# 2023.10.26 - updated auth validation to use basicClusterInfo, fixed copySessionCookie function
# 2023.11.07 - updated password storage after validation
# 2023.11.08 - fixed toJson function duplicate output
# 2023.11.18 - fix reportError quiet mode
# 2023.11.27 - fix useApiKey for helios/mcm
# 2023.11.30 - implemented apiauth_legacy function
# 2023.12.01 - added -noDomain (for SaaS connector)
# 2023.12.03 - added support for raw URL
# 2023.12.13 - re-ordered apiauth parameters (to force first unnamed parameter to be interpreted as password)
#
# . . . . . . . . . . . . . . . . . . .
