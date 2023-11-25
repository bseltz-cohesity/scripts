# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$targetCluster,
    [Parameter(Mandatory = $True)][string]$targetUser,
    [Parameter()][string]$targetDomain = 'local',
    [Parameter()][string]$sourceCluster,
    [Parameter()][string]$sourceUser = $targetUser,
    [Parameter()][string]$sourceDomain = $targetDomain,
    [Parameter()][switch]$useApiKeys,
    [Parameter()][switch]$promptForMfaCode,
    [Parameter()][switch]$restore
)

if(! $restore -and (! $sourceCluster -or ! $sourceUser)){
    Write-Host "Please specify -restore, or -sourceCluster and -sourceUser" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# functions -----------------------------------------------------
function checkClusterVersion(){
    if($cluster.clusterSoftwareVersion -lt '6.8.1_u5'){
        Write-Host "This script requires Cohesity version 6.8.1_u5 or later" -ForegroundColor Yellow
        exit 1
    }
}

function setGflag($vip, $servicename='magneto', $flagname='magneto_skip_cert_upgrade_for_multi_cluster_registration', $flagvalue='false', $reason='Enable agent certificate update'){

    $gflagAlreadySet = $false
    $gflags = (api get /nexus/cluster/list_gflags).servicesGflags

    foreach($service in $gflags){
        $svcName = $service.serviceName
        if($svcName -eq $servicename){
            $serviceGflags = $service.gflags
            foreach($serviceGflag in $serviceGflags){
                if($serviceGflag.name -eq $flagname -and $serviceGflag.value -eq $flagvalue){
                    Write-Host "Gflag already set"
                    $gflagAlreadySet = $True
                }
            }
        }
    }

    if(! $gflagAlreadySet){
        $nodes = api get nodes
        write-host "Setting gflag  $($servicename):  $flagname = $flagvalue"
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
        $null = api post '/nexus/cluster/update_gflags' $gflagReq
        Write-Host "    making effective now on all nodes:"
        foreach($node in $nodes){
            Write-Host "        $($node.ip)"
            if($PSVersionTable.PSEdition -eq 'Core'){
                $null = Invoke-WebRequest -UseBasicParsing -Uri "https://$vip/siren/v1/remote?relPath=&remoteUrl=http%3A%2F%2F$($node.ip)%3A$('20000')%2Fflagz%3F$flagname=$flagvalue" -Headers $cohesity_api.header -SkipCertificateCheck -WebSession $thisContext.session
            }else{
                $null = Invoke-WebRequest -UseBasicParsing -Uri "https://$vip/siren/v1/remote?relPath=&remoteUrl=http%3A%2F%2F$($node.ip)%3A$('20000')%2Fflagz%3F$flagname=$flagvalue" -Headers $cohesity_api.header -WebSession $thisContext.session
            }
        }
    }
}

function copyCerts($certs){
    $params = @{
        "privateKey" = $certs.privateKey;
        "caChain" = $certs.caChain
    }
    $result = api post -v2 cert-manager/bootstrap-ca $params
    $newCaChain = ''
    while($certs.caChain -ne $newCaChain){
        Start-Sleep 10
        $newCerts = api get -v2 cert-manager/ca-status
        $newCaChain = $newCerts.caCertChain
    }
}

# main ----------------------------------------------------------
if(! $restore){
    $cacheFile = "$($sourceCluster)-Certs.json"
    if(Test-Path -Path $cacheFile -PathType Leaf){
        "`nUsing cached keys from source cluster $sourceCluster..."
        $certs = Get-Content -Path $cacheFile | ConvertFrom-Json
    }else{
        "`nConnecting to source cluster $sourceCluster..."
        $mfaCode = $null
        if($promptForMfaCode){
            $mfaCode = Read-Host -Prompt 'Please Enter MFA Code'
        }
        apiauth -vip $sourceCluster -username $sourceUser -domain $sourceDomain -apiKeyAuthentication $useApiKeys -mfaCode $mfaCode -quiet
        
        $cluster = api get cluster
        
        # check cluster version
        checkClusterVersion
    
        # get certs
        Write-Host "Getting certs"
        $certs = api get -v2 cert-manager/ca-keys
        $certs | toJson | Out-File -FilePath $cacheFile
        setGflag -vip $sourceCluster
    }
}

"`nConnecting to target cluster $targetCluster..."
$mfaCode = $null
if($promptForMfaCode){
    $mfaCode = Read-Host -Prompt 'Please Enter MFA Code'
}
apiauth -vip $targetCluster -username $targetUser -domain $targetDomain -apiKeyAuthentication $useApiKeys -mfaCode $mfaCode -quiet

$cluster = api get cluster

# check cluster version
checkClusterVersion

$cacheFile = "$($cluster.name)-Certs.json"

# restore original certs
if($restore){
    if(Test-Path -Path $cacheFile -PathType Leaf){
        Write-Host "Restoring original certs"
        $certs = Get-Content -Path $cacheFile | ConvertFrom-Json
        copyCerts $certs
        Write-Host "Restore completed`n"
        exit
    }else{
        Write-Host "No backup found for $sourceCluster`n" -ForegroundColor Yellow
        exit
    }
}

# backup original certs
$origCerts = api get -v2 cert-manager/ca-keys
if(! (Test-Path -Path $cacheFile -PathType Leaf)){
    $origCerts | toJson | Out-File -FilePath $cacheFile
}

# copy new certs
Write-Host "Copying certs"
copyCerts $certs

# set gflag
setGflag -vip $targetCluster
Write-Host "`nProcess finished`n"
