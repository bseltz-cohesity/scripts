# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter()][array]$vmName,
    [Parameter()][string]$vmList = '',
    [Parameter()][switch]$deleteSnapshots
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -regionid $region

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$vmNames = @(gatherList -Param $vmName -FilePath $vmList -Name 'VMs' -Required $True)

if($deleteSnapshots){
    $delSnaps = $True
}else{
    $delSnaps = $false
}

$sources = api get -mcmv2 "data-protect/sources?environments=kAWS"
$source = $sources.sources | Where-Object name -eq $sourceName
if(!$source){
    Write-Host "Source $sourceName not found" -ForegroundColor Yellow
    exit
}
$sourceId = $source.sourceInfoList[0].sourceId

foreach($vm in $vmNames){
    $search = api get -v2 "data-protect/search/objects?parentId=$sourceId&onlyProtectedObjects=true&searchString=$vm"
    $results = $search.objects | Where-Object name -eq $vm
    if(! $results){
        Write-Host "$vm not found or not protected" -ForegroundColor Yellow
        continue
    }
    foreach($protectionInfo in $results.objectProtectionInfos){
        $objectId = $protectionInfo.objectId
        $unprotectParams = @{
            "action" = "UnProtect";
            "objectActionKey" = "kAWSNative";
            "unProtectParams" = @{
                "objects" = @(
                    @{
                        "id" = $objectId;
                        "deleteAllSnapshots" = $delSnaps;
                        "forceUnprotect" = $True
                    }
                )
            };
            "snapshotBackendTypes" = @(
                "kAWSNative";
                "kAWSSnapshotManager"
            )
        }
        Write-Host "Unprotecting $vm"
        $null = api post -v2 data-protect/protected-objects/actions $unprotectParams
    }
}
