# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$sourceCluster,
    [Parameter(Mandatory = $True)][string]$sourceUser,
    [Parameter()][string]$sourceDomain = 'local',
    [Parameter(Mandatory = $True)][string]$targetCluster,
    [Parameter()][string]$targetUser = $sourceUser,
    [Parameter()][string]$targetDomain = $sourceDomain,
    [Parameter(Mandatory = $True)][string]$policyName,
    [Parameter()][string]$prefix = '',
    [Parameter()][string]$suffix = '',
    [Parameter()][string]$newPolicyName = $policyName,
    [Parameter()][string]$newReplicaClusterName = $null,
    [Parameter()][hashtable]$newTargetNames = @{},
    [Parameter()][switch]$skipLocalReplica,
    [Parameter()][switch]$skipAllReplicas,
    [Parameter()][switch]$skipAllArchives
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

"`nConnecting to source cluster..."
apiauth -vip $sourceCluster -username $sourceUser -domain $sourceDomain -quiet

if($prefix){
    $newPolicyName = "$prefix-$newPolicyName"
}

if($suffix){
    $newPolicyName = "$newPolicyName-$suffix"
}

$policy = (api get -v2 'data-protect/policies').policies | Where-Object name -eq $policyName
$vaults = api get vaults
$remotes = api get remoteClusters

function clearConfigId($element){
    foreach($prop in $element.PSObject.Properties){
        if($prop.name -eq 'configId'){
            delApiProperty -object $element -name configId
        }else{
            if($prop.TypeNameOfValue -eq "System.Object[]"){
                foreach($child in $element.$($prop.name)){
                    clearConfigId $child
                }
            }
            if($prop.TypeNameOfValue -eq "System.Management.Automation.PSCustomObject"){
                clearConfigId $element.$($prop.name)
            }
        }
    }
}

if($policy){
    clearConfigId $policy

    "Connecting to target cluster..."
    apiauth -vip $targetCluster -username $targetUser -domain $targetDomain -quiet

    $cluster = api get cluster

    # check for existing policy
    $newPolicy = (api get -v2 data-protect/policies).policies | Where-Object name -eq $newPolicyName
    if($newPolicy){
        Write-Host "Policy $newPolicyName already exists" -ForegroundColor Yellow
        exit
    }
    $newVaults = api get vaults
    $newRemotes = api get remoteClusters
    $policy.name = $newPolicyName
    if($policy.PSObject.Properties['remoteTargetPolicy']){
        # replicas
        if($policy.remoteTargetPolicy.PSObject.Properties['replicationTargets']){
            if($skipAllReplicas){
                $policy.remoteTargetPolicy.replicationTargets = @()
            }else{
                foreach($replica in $policy.remoteTargetPolicy.replicationTargets){
                    # delApiProperty -object $replica -name configId
                    $migrateReplica = $True
                    $remoteClusterName = $replica.remoteTargetConfig.clusterName
                    if($remoteClusterName -eq $cluster.name){
                        if($skipLocalReplica){
                            $migrateReplica = $false
                        }else{
                            if($newReplicaClusterName){
                                $remoteClusterName = $newReplicaClusterName
                            }else{
                                Write-Host "replica points to target cluster. Please specify -newReplicaClusterName" -ForegroundColor Yellow
                                exit
                            }
                        }
                    }
                    if($True -eq $migrateReplica){
                        $newRemote = $newRemotes | Where-Object name -eq $remoteClusterName
                        if(!$newRemote){
                            Write-Host "Remote cluster $remoteClusterName is not registered on the target cluster" -ForegroundColor Yellow
                            exit
                        }else{
                            $replica.remoteTargetConfig.clusterId = $newRemote.clusterId
                        }
                    }else{
                        $policy.remoteTargetPolicy.replicationTargets = @($policy.remoteTargetPolicy.replicationTargets | Where-Object {$_.remoteTargetConfig.clusterName -ne $replica.remoteTargetConfig.clusterName})
                    }
                }
            }
        }
        # archives
        if($policy.remoteTargetPolicy.PSObject.Properties['archivalTargets']){
            if($skipAllArchives){
                $policy.remoteTargetPolicy.archivalTargets = @()
            }else{
                foreach($archival in $policy.remoteTargetPolicy.archivalTargets){
                    # delApiProperty -object $archival -name configId
                    $targetName = $archival.targetName                   
                    if($newTargetNames[$targetName]){
                        $targetName = $newTargetNames[$targetName]
                    }
                    $newVault = $newVaults | Where-Object name -eq $targetName
                    if(!$newVault){
                        Write-Host "Archive target $targetName not found on the target cluster" -ForegroundColor Yellow
                        exit
                    }else{
                        $archival.targetId = $newVault.id
                        $archival.targetName = $targetName
                    }
                }
            }
        }
        # not migrating cloudSpin
        if($policy.remoteTargetPolicy.PSObject.Properties['cloudSpinTargets']){
            $policy.remoteTargetPolicy.cloudSpinTargets = @()
        }
    }

    "Migrating policy..."
    $null = api post -v2 data-protect/policies $policy

}else{
    Write-Host "Policy $policyName not found" -ForegroundColor Yellow
}
