# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter()][int]$streamCount = 3,
    [Parameter()][int]$pageSize = 1000,
    [Parameter()][switch]$commit,
    [Parameter()][array]$serverName,  # optional names of mailboxes protect
    [Parameter()][string]$serverList = ''  # optional textfile of mailboxes to protect
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


$serverNames = @(gatherList -Param $serverName -FilePath $serverList -Name 'servers' -Required $False)

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
$paginationCookie = 0
$x = 0
while($true){
    $search = api get -v2 "data-protect/search/objects?environments=kSQL&regionIds=$regionList&isProtected=true&includeTenants=true&count=$pageSize&paginationCookie=$paginationCookie"
    if($search.count -eq 0){
        break
    }else{
        foreach($result in $search.objects | Sort-Object -Property {$_.sourceInfo.name}, {$_.name}){
            if($serverNames.Count -eq 0 -or $result.sourceInfo.name -in $serverNames){
                $x += 1
                foreach($objectProtectionInfo in $result.objectProtectionInfos){
                    $objectId = $objectProtectionInfo.objectId
                    $objectRegionId = $objectProtectionInfo.regionId
                    $obj = api get -v2 "data-protect/objects?ids=$objectId&regionId=$objectRegionId"
                    foreach($o in $obj.objects){
                        $currentStreamCount = $o.objectBackupConfiguration.mssqlParams.commonNativeObjectProtectionTypeParams.numStreams
                        Write-Host "$($result.sourceInfo.name)/$($result.name) ($currentStreamCount)"
                        if($commit -and $streamCount -ne $currentStreamCount){
                            $o.objectBackupConfiguration.mssqlParams.commonNativeObjectProtectionTypeParams.numStreams = $streamCount
                            $opId = $o.id
                            if($o.objectBackupConfiguration.isAutoProtectConfig -eq $True){
                                $opId = $o.objectBackupConfiguration.autoProtectParentId
                            }
                            Write-Host "    --> $streamCount"
                            $updated = api put -v2 "data-protect/protected-objects/$($opId)?regionId=$objectRegionId" $o.objectBackupConfiguration
                        }
                    }
                }
            }
        }
    }
    if($search.count -eq $search.paginationCookie){
        break
    }
    $paginationCookie += $pageSize
}
if($x -eq 0){
    Write-Host "No SQL databases found or updated" -ForegroundColor Yellow
}
