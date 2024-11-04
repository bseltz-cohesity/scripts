### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][switch]$stop,
    [Parameter()][switch]$start,
    [Parameter()][switch]$wait
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    if($emailMfaCode){
        apiauth -vip $vip -username $username -domain $domain -password $password -emailMfaCode
    }else{
        apiauth -vip $vip -username $username -domain $domain -password $password -mfaCode $mfaCode
    }
}

function wait_for_sync($starting=$false){
    $synced = $false
    $correctState = $false
    while($synced -eq $false -or $correctState -eq $false){
        Start-Sleep 5
        apiauth -vip $vip -username $username -domain $domain -Quiet
        if($cohesity_api.authorized){
            $stat = api get /nexus/cluster/status -quiet
            if($stat){
                if($stat.isServiceStateSynced -eq $True){
                    $synced = $True
                }
                if($stat.bulletinState.runAllServices -eq $starting){
                    $correctState = $True
                }
            }
        }
    }
}

$stat = api get /nexus/cluster/status
$clusterId = $stat.clusterId

if($stop){
    $stopping = api post /nexus/cluster/stop @{"clusterId" = $clusterId}
    $stopping.message
    if($wait){
        wait_for_sync $false
        "Cluster stopped successfully"
    }
}

if($start){
    $starting = api post /nexus/cluster/start @{"clusterId" = $clusterId}
    $starting.message
    if($wait){
        wait_for_sync $True
        "Cluster started successfully"
    }
}
