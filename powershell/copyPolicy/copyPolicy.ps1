# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$policyName,
    [Parameter()][string]$newPolicyName,
    [Parameter()][switch]$export,
    [Parameter()][switch]$import,
    [Parameter()][string]$configFolder = './configExports'  # folder to store export files
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

# create export folder
$configPath = Join-Path -Path $configFolder -ChildPath $cluster.name 
if(! (Test-Path -PathType Container -Path $configPath)){
    $null = New-Item -ItemType Directory -Path $configPath -Force
}

$policies = api get protectionPolicies
if(! $newPolicyName){
    $newPolicyName = $policyName
}

if($export){
    $policy = $policies | Where-Object name -eq $policyName
    if(! $policy){
        Write-Host "Policy $policyName not found" -ForegroundColor Yellow
        exit
    }
    Write-Host "Exporting policy $policyName..."
    $policy | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configPath -ChildPath "$policyName.json")
}elseif($import){
    $policyPath = Join-Path -Path $configFolder -ChildPath "$policyName.json"
    if(! (Test-Path -PathType Leaf -Path $policyPath)){
        Write-Host "policies file not found" -ForegroundColor Yellow
        exit
    }
    $oldPolicy = get-content $policyPath | ConvertFrom-Json
    $oldPolicy | delApiProperty -name snapshotReplicationCopyPolicies
    $oldPolicy | delApiProperty -name snapshotArchivalCopyPolicies
    $oldPolicy | delApiProperty -name cloudDeployPolicies
    $oldPolicy | delApiProperty -name id
    $oldPolicy.name = $newPolicyName
    $newPolicy = $policies | Where-Object name -eq $newPolicyName
    if($newPolicy){
        Write-Host "Policy $newPolicyName already exists" -ForegroundColor Blue
    }else{
        write-host "Importing policy $newPolicyName..."
        $newPolicy = api post protectionPolicies $oldPolicy
    }
}
