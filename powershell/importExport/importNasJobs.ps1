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

# get storageDomain file
$jobsPath = Join-Path -Path $configFolder -ChildPath 'jobs.json'
if(! (Test-Path -PathType Leaf -Path $jobsPath)){
    Write-Host "jobs file not found" -ForegroundColor Yellow
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

$parentId = (api get protectionSources?environment=kGenericNas).protectionSource.id

$newJobs = api get protectionJobs
$oldNasJobs = (get-content $jobsPath | ConvertFrom-Json) | Where-Object {$_.environment -eq 'kGenericNas' -and $_.isDeleted -ne $True -and $_.isActive -ne $false}

foreach($oldJob in $oldNasJobs){
    $oldId = $oldJob.id
    $oldName = "Imported from $oldClusterName - $($oldJob.name)"
    $newJob = $newJobs | Where-Object {$_.name -eq $oldName}
    if(! $newJob){
        write-host "Importing Job $oldName" -ForegroundColor Green
        $oldJob | delApiProperty -name id
        $oldJob.policyId = $idmap[$oldJob.policyId]
        $oldJob.viewBoxId = [int]$idmap["$($oldJob.viewBoxId)"]
        $oldJob.parentSourceId = $parentId
        $oldJob.name = $oldName
        $newSources = @()
        foreach($sourceId in $oldJob.sourceIds){
            $newSources += [int]$idmap["$sourceId"]
        }
        $oldJob.sourceIds = $newSources
        $newJob = api post protectionJobs $oldJob
    }else{
        write-host "Job $oldName already exists" -ForegroundColor Blue
    }
    $newId = $newJob.id
    $idmap["$newId"] = $oldId
}
# store id map
$idmap.Keys | ForEach-Object { "$($_)=$($idmap[$_])" } | Out-File -FilePath $idMapPath
