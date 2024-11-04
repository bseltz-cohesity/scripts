# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'Ccs',
    [Parameter()][array]$objectName,  # optional names of mailboxes protect
    [Parameter()][string]$objectListList = '',  # optional textfile of mailboxes to protect
    [Parameter(Mandatory = $True)][int]$incrementalSlaMinutes,  # incremental SLA minutes
    [Parameter(Mandatory = $True)][int]$fullSlaMinutes,  # full SLA minutes
    [Parameter()][int]$pageSize = 1000
)


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


$objectNames = @(gatherList -Param $objectName -FilePath $objectList -Name 'objects' -Required $True)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$sessionUser = api get sessionUser
$tenantId = $sessionUser.profiles[0].tenantId
$regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
$regionList = $regions.tenantRegionInfoList.regionId -join ','

foreach($objName in $objectNames){
    $search = api get -v2 "data-protect/search/objects?searchString=$objName&regionIds=$regionList&isProtected=true&includeTenants=true&count=$pageSize"
    if($search.count -eq 0){
        Write-Host "$objName not found" -ForegroundColor Yellow
    }else{
        $x = 0
        foreach($result in $search.objects | Where-Object {$_.name -eq $objName}){
            Write-Host $objName
            $x += 1
            foreach($objectProtectionInfo in $result.objectProtectionInfos){
                $objectId = $objectProtectionInfo.objectId
                $objectRegionId = $objectProtectionInfo.regionId
                $obj = api get -v2 "data-protect/objects?ids=$objectId&regionId=$objectRegionId"
                foreach($o in $obj.objects){
                    $currentIncrementalSla = ($o.objectBackupConfiguration.sla | Where-Object {$_.backupRunType -eq 'kIncremental'}).slaMinutes
                    $currentFullSla = ($o.objectBackupConfiguration.sla | Where-Object {$_.backupRunType -eq 'kFull'}).slaMinutes
                    if($incrementalSlaMinutes -ne $currentIncrementalSla -or $fullSlaMinutes -ne $currentIncrementalSla){
                        $o.objectBackupConfiguration.sla = @(
                            @{
                                "backupRunType" = "kIncremental";
                                "slaMinutes" = $incrementalSlaMinutes
                            };
                            @{
                                "backupRunType" = "kFull";
                                "slaMinutes" = $fullSlaMinutes
                            }
                        )
                        $opId = $o.id
                        if($o.objectBackupConfiguration.isAutoProtectConfig -eq $True){
                            $opId = $o.objectBackupConfiguration.autoProtectParentId
                        }
                        if($o.objectBackupConfiguration.environment -eq 'kO365'){
                            $o.objectBackupConfiguration.environment = $o.objectBackupConfiguration.office365Params.objectProtectionType -replace "^k", "kO365"
                            if($o.objectBackupConfiguration.environment -eq 'kO365Mailbox'){
                                $o.objectBackupConfiguration.environment = 'kO365Exchange'
                            }
                            if($o.objectBackupConfiguration.environment -eq 'kO365SharePoint'){
                                $o.objectBackupConfiguration.environment = 'kO365Sharepoint'
                            }
                            if($o.objectBackupConfiguration.environment -eq 'kO365Teams'){
                                $o.objectBackupConfiguration.office365Params.teamsObjectProtectionParams.objects = @(@{'id' = $opId})
                            }
                        }
                        $updated = api put -v2 "data-protect/protected-objects/$($opId)?regionId=$objectRegionId" $o.objectBackupConfiguration
                    }
                }
            }
        }
        if($x -eq 0){
            Write-Host "$objName not found" -ForegroundColor Yellow
        }
    }
}
