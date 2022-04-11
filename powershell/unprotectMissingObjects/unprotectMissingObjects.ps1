# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
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


foreach($job in $jobs.protectionGroups | Where-Object environment -ne 'kView' | Sort-Object -Property name){
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        $jobChanged = $False
        $jobParams = findObjectParam $job
        $reported = @()
        foreach($param in $jobParams){
            if($param.PSObject.Properties['objects']){
                foreach($object in $param.objects){
                    $objIdsToDelete = @()
                    $objectId = [string]($object.id)
                    $sourceId = [string]($object.sourceId)
                    if(!$objectId){
                        $objectId = $sourceId
                    }
                    $thisObject = api get protectionSources/objects/$objectId -quiet
                    if($thisObject -eq $null){
                        "Removing $($object.name) from $($job.name)" | Tee-Object -FilePath $outfileName -Append
                        $objIdsToDelete = @($objIdsToDelete + $objectId)
                        $jobChanged = $True
                        $param.objects = @($param.objects | Where-Object {$_.id -ne $objectId -and $_.sourceId -ne $objectId})
                    }
                }
                if($jobChanged){
                    if($param.objects.Count -eq 0){
                        # delete the job
                        "JOB: $($job.name) would have no objects left, can be deleted" | Tee-Object -FilePath $outfileName -Append
                        # $null = api delete -v2 "data-protect/protection-groups/$($job.id)"
                    }else{
                        # update the job
                        $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
                    }
                }
            }
        }
    }
}

"`nOutput saved to $outfilename`n"
