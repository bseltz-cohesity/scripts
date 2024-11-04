# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][array]$dbName,
    [Parameter()][string]$dbList,
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][array]$serverName,
    [Parameter()][string]$serverList
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

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $false)
$serverNames = @(gatherList -Param $serverName -FilePath $serverList -Name 'servers' -Required $True)
$dbNames = @(gatherList -Param $dbName -FilePath $dbList -Name 'jobs' -Required $false)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

$jobs = api get -v2 "data-protect/protection-groups?environments=kOracle&isActive=true&isDeleted=false"

if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

$sources = api get protectionSources?environments=kOracle

$notfoundServers = $serverNames | Where-Object {$_ -notin $sources.nodes.protectionSource.name}
if($notfoundServers){
    Write-Host "Servers not found $($notfoundServers -join ', ')" -ForegroundColor Yellow
    exit 1
}

foreach($thisServer in $serverNames){
    $idsToRemove = @()
    $objectName = @{}
    $noProtections = $True

    # gather source IDs
    $thisSource = $sources.nodes | Where-Object {$_.protectionSource.name -eq $thisServer}
    if($dbNames.Count -eq 0){
        $idsToRemove = @($idsToRemove + $thisSource.protectionSource.id)
        $objectName["$($thisSource.protectionSource.id)"] = $thisSource.protectionSource.name
    }
    foreach($instance in $thisSource.applicationNodes){
        if($dbNames.Count -eq 0 -or $instance.protectionSource.name -in $dbNames){
            $idsToRemove = @($idsToRemove + $instance.protectionSource.id)
            $objectName["$($instance.protectionSource.id)"] = "$($thisSource.protectionSource.name)/$($instance.protectionSource.name)"
        }
    }

    # find source IDs in jobs
    foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
        $removingFromJob = $false
        if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
            # remove source IDs from job
            foreach($object in $job.oracleParams.objects){
                if($object.sourceId -in $idsToRemove){
                    $noProtections = $false
                    $removingFromJob = $True
                    $job.oracleParams.objects = @($job.oracleParams.objects | Where-Object {$_.sourceId -ne $object.sourceId})
                    Write-Host "Unprotecting $($objectName["$($object.sourceId)"]) from $($job.name)"
                }else{
                    foreach($dbParam in $object.dbParams){
                        if($dbParam.databaseId -in $idsToRemove){
                            $noProtections = $false
                            $removingFromJob = $True
                            $object.dbParams = @($object.dbParams | Where-Object {$_.databaseId -ne $dbParam.databaseId})
                            Write-Host "Unprotecting $($objectName["$($dbParam.databaseId)"]) from $($job.name)"
                        }
                        if($object.dbParams.Count -eq 0){
                            $job.oracleParams.objects = @($job.oracleParams.objects | Where-Object {$_.sourceId -ne $object.sourceId})
                        }
                    }
                }
            }
            if($removingFromJob -eq $True){
                if($job.oracleParams.objects.Count -eq 0){
                    Write-Host "Deleting job $($job.name) (no objects left)"
                    $null = api delete -v2 "data-protect/protection-groups/$($job.id)?deleteSnapshots=false"
                }else{
                    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
                }
            }
        }
    }
    if($noProtections -eq $True){
        Write-Host "No protections found for $thisServer"
    }
}
