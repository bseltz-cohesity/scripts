# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'ccs',
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][array]$sourceName,
    [Parameter()][string]$sourceList,
    [Parameter()][string]$region,
    [Parameter()][switch]$wait,
    [Parameter()][int]$sleepTime = 15
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

$sourceNames = @(gatherList -Param $sourceName -FilePath $sourceList -Name 'source names' -Required $True)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -passwd $password -noPromptForPassword $noPrompt # -regionid $region 

if(!$region){
    $sessionUser = api get sessionUser
    $tenantId = $sessionUser.profiles[0].tenantId
    $regions = api get -mcmv2 dms/tenants/regions?tenantId=$tenantId
    $regionList = $regions.tenantRegionInfoList.regionId -join ','
    $sources = api get -mcmv2 "data-protect/sources?regionIds=$regionList&excludeProtectionStats=true"
}else{
    $sources = api get -mcmv2 "data-protect/sources?regionIds=$region&excludeProtectionStats=true"
}

foreach($sName in $sourceNames){
    $thisSource = $sources.sources | Where-Object name -eq $sName
    if(! $thisSource){
        Write-Host "Protection source $sName not found" -ForegroundColor Yellow
        continue
    }
    foreach($source in $thisSource){
        foreach($sourceInfo in $source.sourceInfoList){
            $sourceId = $sourceInfo.sourceId
            $regionId = $sourceInfo.regionId
            Write-Host "Refreshing $($source.name) ($($regionId))"
            $refresh = api post "protectionSources/refresh/$($sourceId)?regionId=$($regionId)"
        }
    }
}



if($wait){
    $finished = $False
    while($finished -eq $False){
        $finished = $True
        Start-Sleep $sleepTime
        foreach($sName in $sourceNames){
            $thisSource = $sources.sources | Where-Object name -eq $sName
            if(! $thisSource){
                continue
            }
            foreach($source in $thisSource){
                foreach($sourceInfo in $source.sourceInfoList){
                    $sourceId = $sourceInfo.sourceId
                    $regionId = $sourceInfo.regionId
                    $status = api get -v2 "data-protect/sources/registrations?ids=$($sourceId)&regionId=$($regionId)"
                    Write-Host "$($source.name) ($($status.registrations[0].authenticationStatus))"
                    if($status.registrations[0].authenticationStatus -ne 'Finished'){
                        $finished = $False
                    }
                }
            }
        }
    }
}
