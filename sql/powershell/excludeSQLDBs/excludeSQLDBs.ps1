# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][array]$filter,
    [Parameter()][string]$filterList,
    [Parameter()][array]$regex,
    [Parameter()][string]$regexList,
    [Parameter()][switch]$clear
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

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
$filters = @(gatherList -Param $filter -FilePath $filterList -Name 'jobs' -Required $false)
$regexes = @(gatherList -Param $regex -FilePath $regexList -Name 'jobs' -Required $false)

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&environments=kSQL"

if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

$paramName = @{
    'kFile' = 'fileProtectionTypeParams';
    'kVolume' = 'volumeProtectionTypeParams';
    'kNative' = 'nativeProtectionTypeParams'
}

$newExclusions = $False
if($filters -or $regexes){
    $newExclusions = $True
}

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        Write-Host $job.name
        $params = $job.mssqlParams.$($paramName[$job.mssqlParams.protectionType])
        if($clear){
            delApiProperty -object $params -name excludeFilters
        }
        if($newExclusions){
            if(! $params.PSObject.Properties['excludeFilters']){
                setApiProperty -object $params -name excludeFilters -value @()
            }
            foreach($filterItem in $filters){
                $params.excludeFilters = @(@($params.excludeFilters | Where-Object {$_.filterString -ne $filterItem}) + @{"filterString" = $filterItem; "isRegularExpression" = $False})
            }
            foreach($filterItem in $regexes){
                $params.excludeFilters = @(@($params.excludeFilters | Where-Object {$_.filterString -ne $filterItem}) + @{"filterString" = $filterItem; "isRegularExpression" = $True})
            }
        }
        foreach($exclusion in $params.excludeFilters){
            if($exclusion.isRegularExpression){
                Write-Host "    $($exclusion.filterString) (Regex)"
            }else{
                Write-Host "    $($exclusion.filterString)"
            }
        }
        if($clear -or $newExclusions){
            $null = api put -v2 data-protect/protection-groups/$($job.id) $job
        }
    }
}
