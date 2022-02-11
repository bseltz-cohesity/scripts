# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][array]$objectName,
    [Parameter()][string]$objectList,
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList
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
$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $False)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

# outfile
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "log-unprotectObjects-$dateString.txt"

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true"

if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found: $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

$unprotected = @{}

function findObjectParam($o){
    $jobParams = $o.PSObject.Properties.Name -match 'params'
    foreach($param in $jobParams){
        if($o.$param.PSObject.Properties['objects']){
            $objectParam = $o.$param
        }elseif($o.$param.PSObject.Properties.Name -match 'params'){
            $objectParam = findObjectParam $o.$param
        }
    }
    return $objectParam
}

$idToName = @{}

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        $jobChanged = $False
        $jobParams = findObjectParam $job
        foreach($param in $jobParams){
            if($param.PSObject.Properties['objects']){
                foreach($objName in $objectNames){
                    foreach($object in $param.objects){
                        
                        if($object.PSObject.Properties['name']){
                            $thisObjectName = $object.Name
                        }else{
                            $objectId = [string]($object.id)
                            $sourceId = [string]($object.sourceId)
                            if(!$objectId){
                                $objectId = $sourceId
                            }
                            if($idToName.ContainsKey($objectId)){
                                $thisObjectName = $idToName[$objectId]
                            }else{
                                $thisObjectName = (api get protectionSources/objects/$objectId).name
                                $idToName[$objectId] = $thisObjectName
                            }
                        }
                        if($objName -eq $thisObjectName){
                            "UNPROTECTING: $($objName) (from $($job.name))" | Tee-Object -FilePath $outfileName -Append
                            $unprotected[$objName] = 1
                            $jobChanged = $True
                            $param.objects = @($param.objects | Where-Object name -ne $objName)
                        }
                    }
                }
                if($jobChanged){
                    if($param.objects.Count -eq 0){
                        # delete the job
                        "DELETING JOB: $($job.name) (no objects left)" | Tee-Object -FilePath $outfileName -Append
                        $null = api delete -v2 "data-protect/protection-groups/$($job.id)"
                    }else{
                        # update the job
                        $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
                    }
                }
            }
        }
    }
}

foreach($objName in $objectNames){
    if($objName -notin $unprotected.Keys){
        "    NOTFOUND: $objName (not found in specified jobs)" | Tee-Object -FilePath $outfileName -Append
    }
}

"`nOutput saved to $outfilename`n"
