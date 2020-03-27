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

# get storageDomain file
$storageDomainPath = Join-Path -Path $configFolder -ChildPath 'storageDomains.json'
if(! (Test-Path -PathType Leaf -Path $storageDomainPath)){
    Write-Host "storageDomain file not found" -ForegroundColor Yellow
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

$newStorageDomains = api get viewBoxes
$oldStorageDomains = get-content $storageDomainPath | ConvertFrom-Json

foreach($oldStorageDomain in $oldStorageDomains){
    $oldId = $oldStorageDomain.id
    $oldName = $oldStorageDomain.name
    $newStorageDomain = $newStorageDomains | Where-Object {$_.name -eq $oldName}
    if(! $newStorageDomain){
        write-host "Importing Storage domain $oldName" -ForegroundColor Green
        $oldStorageDomain | delApiProperty -name id
        $newStorageDomain = api post viewBoxes $oldStorageDomain
    }else{
        write-host "Storage domain $oldName already exists" -ForegroundColor Blue
    }
    $newId = $newStorageDomain.id
    $idmap["$newId"] = $oldId
}
# store id map
$idmap.Keys | ForEach-Object { "$($_)=$($idmap[$_])" } | Out-File -FilePath $idMapPath
