# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$configFolder  # folder to store export files
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

# get cluster file
$clusterPath = Join-Path -Path $configFolder -ChildPath 'cluster.json'
if(! (Test-Path -PathType Leaf -Path $clusterPath)){
    Write-Host "cluster file not found" -ForegroundColor Yellow
    exit
}
$oldClusterName = (get-content $clusterPath | ConvertFrom-Json).name

# get sources file
$policyPath = Join-Path -Path $configFolder -ChildPath 'policies.json'
if(! (Test-Path -PathType Leaf -Path $policyPath)){
    Write-Host "policies file not found" -ForegroundColor Yellow
    exit
}

# get id map
$idmap = @{}
$idMapPath = Join-Path -Path $configFolder -ChildPath 'idmap.json'
if(Test-Path -PathType Leaf -Path $idMapPath){
    foreach($mapentry in (Get-Content $idMapPath)){
        $oldId, $newId = $mapentry.Split('=')
        $idmap[$oldId] = $newId
    }
}

$newPolicies = api get protectionPolicies
$oldPolicies = get-content $policyPath | ConvertFrom-Json

foreach($oldPolicy in $oldPolicies){
    $oldId = $oldPolicy.id
    $oldPolicy | delApiProperty -name snapshotReplicationCopyPolicies
    $oldPolicy | delApiProperty -name snapshotArchivalCopyPolicies
    $oldPolicy | delApiProperty -name cloudDeployPolicies
    $oldPolicy | delApiProperty -name id
    $oldPolicy.name = "Imported from $oldClusterName - $($oldPolicy.name)"
    $newPolicy = $newPolicies | Where-Object {$_.name -eq $oldPolicy.name}
    if($newPolicy){
        Write-Host "Policy ""$($oldPolicy.name)"" already imported" -ForegroundColor Blue
    }else{
        write-host "Importing policy ""$($oldPolicy.name)""" -ForegroundColor Green
        $newPolicy = api post protectionPolicies $oldPolicy
    }
    $newId = $newPolicy.id
    $idmap["$oldId"] = $newId
}
# store id map
$idmap.Keys | ForEach-Object { "$($_)=$($idmap[$_])" } | Out-File -FilePath $idMapPath
