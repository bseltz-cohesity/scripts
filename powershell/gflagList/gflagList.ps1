### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter(Mandatory = $True)][string]$serviceName
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}
# end authentication =========================================

$port = @{
    "nexus" = "23456";
    "iris" = "443";
    "stats" = "25566";
    "eagle_agent" = "23460";
    "vault_proxy" = "11115";
    "athena" = "25681";
    "iris_proxy" = "24567";
    "atom" = "20005";
    "smb2_proxy" = "20007";
    "bifrost_broker" = "29992";
    "bifrost" = "29994";
    "alerts" = "21111";
    "bridge" = "11111";
    "keychain" = "22000";
    "smb_proxy" = "20003";
    "bridge_proxy" = "11116";
    "groot" = "26999";
    "apollo" = "24680";
    "tricorder" = "23458";
    "magneto" = "20000";
    "rtclient" = "12321";
    "nexus_proxy" = "23457";
    "gandalf" = "22222";
    "patch" = "30000";
    "librarian" = "26000";
    "yoda" = "25999";
    "storage_proxy" = "20001";
    "statscollector" = "25680";
    "newscribe" = "12222";
    "icebox" = "29999";
    "janus" = "64001";
    "pushclient" = "64002";
    "nfs_proxy" = "20010";
    "throttler" = "20008";
    "elrond" = "26002";
    "heimdall" = "26200";
    "node_exporter" = "9100";
    "compass" = "25555";
    "etl_server" = "23462"
}
$nodes = api get nodes
foreach($node in $nodes){
    copySessionCookie $node.ip
    try{
        if($serviceName -in $port.keys){
            $ProgressPreference = 'SilentlyContinue'
            if($PSVersionTable.PSEdition -eq 'Core'){
                if($servicename -eq 'iris'){
                    $currentFlags = Invoke-WebRequest -UseBasicParsing -Uri "https://$($node.ip):443/flagz" -Headers $cohesity_api.header -WebSession $cohesity_api.session -SkipCertificateCheck
                }else{
                    $currentFlags = Invoke-WebRequest -UseBasicParsing -Uri "https://$vip/siren/v1/remote?relPath=&remoteUrl=http%3A%2F%2F$($node.ip)%3A$($port[$servicename])%2Fflagz" -Headers $cohesity_api.header -WebSession $cohesity_api.session -SkipCertificateCheck
                }
            }else{
                if($servicename -eq 'iris'){
                    $currentFlags = Invoke-WebRequest -UseBasicParsing -Uri "https://$($node.ip):443/flagz" -Headers $cohesity_api.header -WebSession $cohesity_api.session
                }else{
                    $currentFlags = Invoke-WebRequest -UseBasicParsing -Uri "https://$vip/siren/v1/remote?relPath=&remoteUrl=http%3A%2F%2F$($node.ip)%3A$($port[$servicename])%2Fflagz" -Headers $cohesity_api.header -WebSession $cohesity_api.session
                }
            }
            $ProgressPreference = 'Continue'
            $content = $currentFlags.Content
            $flags = $content -split "\n" | Where-Object {$_.startsWith('--')}
            $flags | Sort-Object
            break
        }else{
            Write-Host "service $serviceName not handled" -ForegroundColor Yellow
            exit
        }
    }catch{
        Continue
    }
}


