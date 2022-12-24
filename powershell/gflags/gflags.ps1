### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',   # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username='helios',           # username (local or AD)
    [Parameter()][string]$domain = 'local',            # domain (local or AD FQDN)
    [Parameter()][string]$password,                    # optional password
    [Parameter()][switch]$useApiKey,                   # use API key for authentication
    [Parameter()][string]$accessCluster,               # access cluster (if connectig to helios)
    [Parameter()][switch]$clear,                       # switch to clear a gflag
    [Parameter()][string]$import = '',                 # import from an export file
    [Parameter()][string]$servicename = $null,         # service name to set gflag
    [Parameter()][string]$flagname = $null,            # flag name to set gflag
    [Parameter()][string]$flagvalue = $null,           # flag value to set gflag
    [Parameter()][string]$reason = $null,              # reason to set gflag
    [Parameter()][switch]$effectiveNow,                # switch to set glfag effective now
    [Parameter()][switch]$restart                      # switch restart services
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -password $password -useApiKey 
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password 
}

if($vip -eq 'helios.cohesity.com'){
    if($accessCluster){
        heliosCluster $accessCluster
    }else{
        Write-Host "-accessCluster is required"
        exit
    }
    
}

$port = @{
    'nexus' = '23456';
    'statscollector' = '25680';
    'iris' = '443';
    'nexus_proxy' = '23457';
    'iris_proxy' = '24567';
    'gandalf' = '22222';
    'yoda' = '25999';
    'librarian' = '26000';
    'groot' = '26999';
    'newscribe' = '12222';
    'rtclient' = '12321';
    'keychain' = '22000';
    'apollo' = '24680';
    'bifrost' = '29994';
    'bifrost_broker' = '29992';
    'bridge' = '11111';
    'eagle_agent' = '23460';
    'magneto' = '20000';
    'stats' = '25566';
    'alerts' = '21111';
    'storage_proxy' = '20001';
    'tricorder' = '23458';
    'vault_proxy' = '11115';
    'smb_proxy' = '20003';
    'smb2_proxy' = '20007';
    'bridge_proxy' = '11116';
    'athena' = '25681';
    'atom' = '20005';
    'patch' = '30000';
    'janus' = '64001';
    'pushclient' = '64002';
    'nfs_proxy' = '20010';
    'icebox' = '29999';
    'throttler' = '20008';
    'elrond' = '26002';
    'heimdall' = '26200';
    'node_exporter' = '9100';
    'compass' = '25555';
    'etl_server' = '23462'
}

$cluster = api get cluster
if($effectiveNow){
    $nodes = api get nodes
    $context = getContext
    if($PSVersionTable.PSEdition -eq 'Desktop'){
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true }
        $ignoreCerts = @"
public class SSLHandler
{
    public static System.Net.Security.RemoteCertificateValidationCallback GetSSLHandler()
    {
        return new System.Net.Security.RemoteCertificateValidationCallback((sender, certificate, chain, policyErrors) => { return true;});
    }
}
"@
        if(!("SSLHandler" -as [type])){
            Add-Type -TypeDefinition $ignoreCerts
        }
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [SSLHandler]::GetSSLHandler()
    }
}

function setGflag($servicename, $flagname, $flagvalue, $reason){
    if($clear){
        write-host "clearing  $($servicename):  $flagname"
    }else{
        write-host "setting  $($servicename):  $flagname = $flagvalue"
    }
    $gflagReq = @{
        'clusterId' = $cluster.id;
        'gflags' = @(
            @{
                'name' = $flagname;
                'reason' = $reason;
                'value' = $flagvalue
            }
        );
        'serviceName' = $servicename;
    }
    if($clear){
        $gflagReq['clear'] = $True
    }
    $null = api post '/nexus/cluster/update_gflags' $gflagReq
    if($effectiveNow){
        Write-Host "    making effective now on all nodes:"
        foreach($node in $nodes){
            Write-Host "        $($node.ip)"
            $ProgressPreference = 'SilentlyContinue'
            if($PSVersionTable.PSEdition -eq 'Core'){
                if($servicename -eq 'iris'){
                    $null = Invoke-WebRequest -UseBasicParsing -Uri "https://$($node.ip):443/flagz?$flagname=$flagvalue" -Headers $cohesity_api.header -SkipCertificateCheck
                }else{
                    $null = Invoke-WebRequest -UseBasicParsing -Uri "https://$vip/siren/v1/remote?relPath=&remoteUrl=http%3A%2F%2F$($node.ip)%3A$($port[$servicename])%2Fflagz%3F$flagname=$flagvalue" -Headers $cohesity_api.header -SkipCertificateCheck
                }
            }else{
                if($servicename -eq 'iris'){
                    $null = Invoke-WebRequest -UseBasicParsing -Uri "https://$($node.ip):443/flagz?$flagname=$flagvalue" -Headers $cohesity_api.header
                }else{
                    $null = Invoke-WebRequest -UseBasicParsing -Uri "https://$vip/siren/v1/remote?relPath=&remoteUrl=http%3A%2F%2F$($node.ip)%3A$($port[$servicename])%2Fflagz%3F$flagname=$flagvalue" -Headers $cohesity_api.header
                }
            }
            $ProgressPreference = 'Continue'
        }
    }
}

$restartServices = @()

# set a gflag
if($flagname){
    if(!$servicename){
        Write-Host "-servicename required" -ForegroundColor Yellow
        exit
    }
    if($clear -or ($flagvalue -and $reason)){
        setGflag -servicename $servicename -flagname $flagname -flagvalue $flagvalue -reason $reason
        $restartServices += $servicename
    }else{
        Write-Host "-servicename, -flagname, -flagvalue and -reason are all required to set a gflag" -ForegroundColor Yellow
        exit
    }
    exit
}

# import list of gflags
if($import -ne ''){
    if (!(Test-Path -Path $import)) {
        Write-Host "import file $import not found" -ForegroundColor Yellow
        exit
    }else{
        $imports = Import-Csv -Path $import -Encoding utf8
        foreach($i in $imports){
            $servicename = $null
            $flagname = $null
            $flagvalue = $null
            $reason = $null

            $servicename = $i.serviceName
            $flagname = $i.flagName
            $flagvalue = $i.flagValue
            $reason = $i.reason

            # Write-Host ("setting {0} / {1} : {2} ({3})" -f $servicename, $flagname, $flagvalue, $reason)
            if($servicename -and $flagname -and $flagvalue -and $reason){
                setGflag -servicename $servicename -flagname $flagname -flagvalue $flagvalue -reason $reason
                $restartServices += $servicename
            }else{
                Write-Host "-servicename, -flagname, -flagvalue and -reason are all required to set a gflag" -ForegroundColor Yellow
                exit
            }
        }
    }
    exit 0
}

# show currently set gflags
$gflaglist = @()

$gflags = (api get /nexus/cluster/list_gflags).servicesGflags

foreach($service in $gflags){
    $svcName = $service.serviceName
    $serviceGflags = $service.gflags

    Write-Host "`n$($svcName):"

    foreach($serviceGflag in $serviceGflags){
        $timeStamp = ''
        if($serviceGflag.timestamp -ne 0){
            $timeStamp = $(usecsToDate ($serviceGflag.timestamp * 1000000)).ToString('yyyy-MM-dd')
        }
        Write-Host "    $($serviceGflag.name): $($serviceGflag.value) ($($serviceGflag.reason)) ($timeStamp)"
        $gflaglist += @{'serviceName' = $svcName; 'flagName' = $serviceGflag.name; 'flagValue' = $serviceGflag.value; 'reason' = $serviceGflag.reason; 'timestamp' = $timeStamp}
    }
}

$gflaglist = ($gflaglist | ConvertTo-Json -Depth 99 | ConvertFrom-Json)
$gflaglist | Export-Csv -Path "gflags-$($cluster.name).csv" -Encoding utf8 -NoTypeInformation

Write-Host "`n$($cluster.name) gflags saved to gflags-$($cluster.name).csv`n"

if($restart){
    Write-Host "Restarting required services..."
    $restartParams = @{
        "clusterId" = $cluster.id;
        "services" = @($restartServices)
    }
    $null = api post /nexus/cluster/restart $restartParams
}
