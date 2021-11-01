### usage: ./createProtectionPolicy.ps1 -vip mycluster -username admin -policyName mypolicy -daysToKeep 30 -replicateTo myremotecluster 

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, #Cohesity username
    [Parameter()][string]$domain = 'local', #Cohesity user domain name
    [Parameter(Mandatory = $True)][string]$policyName, #Name of the policy to manage
    [Parameter(Mandatory = $True)][int]$daysToKeep,
    [Parameter(Mandatory = $True)][string]$replicateTo
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### get existing policies
$policies = api get protectionPolicies | Where-Object name -eq $policyName

### get remote clusters
$remotes = api get remoteClusters

$remote = $remotes | Where-Object { $_.name -eq $replicateTo }
if(! $remote){
    Write-Warning "Can't find remote cluster $replicateTo"
    exit
}

if($policies){
    write-warning "policy $policyName already exists"
    exit
}else{
    $newPolicy = @{
        'name' = $policyName;
        'incrementalSchedulingPolicy' = @{
            'periodicity' = 'kDaily';
            'dailySchedule' = @{
                'days' = @()
            }
        };
        'daysToKeep' = $daysToKeep;
        'retries' = 3;
        'retryIntervalMins' = 30;
        'blackoutPeriods' = @();
        'snapshotReplicationCopyPolicies' = @(
            @{
                'copyPartial' = $true;
                'daysToKeep' = $daysToKeep;
                'multiplier' = 1;
                'periodicity' = 'kEvery';
                'target' = @{
                    'clusterId' = $remote.clusterId;
                    'clusterName' = $remote.name
                }
            }
        );
        'snapshotArchivalCopyPolicies' = @();
        'cloudDeployPolicies' = @()
    }
    "creating policy $policyName..."
    $null = api post protectionPolicies $newPolicy
}
