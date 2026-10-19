### usage: ./protectedBy.ps1 -vip 192.168.1.198 -username admin -domain local -object myvm

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$helios,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$object,
    [Parameter()][switch]$returnJobName,
    [Parameter()][string]$jobType,
    [Parameter()][switch]$exactMatchOnly
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $helios -regionid $region -tenant $tenant -noPromptForPassword $noPrompt -quiet

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

$cluster = api get cluster

# get protection jobs
$jobs = api get -v2 "data-protect/protection-groups?isActive=true&isDeleted=False"

if($jobType){
    $jobs.protectionGroups = $jobs.protectionGroups | Where-Object {$_.environment -match $jobType}
}

$foundObject = $false
$script:lastRuns = @{}
$script:notFoundReports = @{}

if(! $returnJobName){
    Write-Host ""
}

$search = api get -v2  "data-protect/search/objects?searchString=$object"
$results = $search.objects
if($exactMatchOnly){
    $results = $search.objects | Where-Object name -eq $object
}
if(! $results.objectProtectionInfos.protectionGroups){
    $search = api get -v2 "data-protect/search/objects?sourceIds=$($results.objectProtectionInfos.objectId -join ',')"
    $results = $search.objects
    if($exactMatchOnly){
        $results = $search.objects | Where-Object name -eq $object
    }
}
foreach($result in $results){
    $foundObject = $True
    $isProtected = $false
    foreach($objectProtectionInfo in $result.objectProtectionInfos){
        foreach($protectionGroup in $objectProtectionInfo.protectionGroups){
            if($protectionGroup.id -in @($jobs.protectionGroups.id)){
                $isProtected = $True
                if($returnJobName){
                    return $protectionGroup.name
                    exit
                }
                Write-Host "  Cluster: $($cluster.name)"
                Write-Host "   Source: $($result.sourceInfo.name)"
                Write-Host "   Object: $($result.name)"
                Write-Host "   PGroup: $($protectionGroup.name)"
                if("$($lastRun.lastRun.id)" -in $script:lastRuns.Keys){
                    $lastRun = $script:lastRuns["$($lastRun.lastRun.id)"]
                }else{
                    $lastRun = api get -v2 "data-protect/protection-groups/$($protectionGroup.id)?includeLastRunInfo=true"
                }       
                if($lastRun.PSObject.Properties['lastRun']){
                    $script:lastRuns["$($lastRun.lastRun.id)"] = $lastRun
                    if($lastRun.lastRun.PSObject.Properties['localBackupInfo']){
                        $startTime = usecsToDate $lastRun.lastRun.localBackupInfo.startTimeUsecs
                        Write-Host " Last Run: $startTime ($($protectionGroup.lastBackupRunStatus))"
                    }elseif($lastRun.lastRun.PSObject.Properties['archivalInfo']){
                        $startTime = usecsToDate $lastRun.lastRun.archivalInfo.archivalTargetResults[0].startTimeUsecs
                        Write-Host " Last Run: $startTime ($($protectionGroup.lastBackupRunStatus))"
                    }
                }else{
                    if($lastRun.isPaused -eq $True){
                        Write-Host " Last Run: N/A (paused)"
                    }else{
                        Write-Host " Last Run: N/A"
                    }
                }
                Write-Host ""
            }
        }
    }
    if(! $isProtected){
        if($returnJobName){
            return $null
        }
        if("$($cluster.name):$($result.sourceInfo.name):$($result.name)" -notin $script:notFoundReports.Keys){
            Write-Host "  Cluster: $($cluster.name)"
            Write-Host "   Source: $($result.sourceInfo.name)"
            Write-Host "   Object: $($result.name)"
            Write-Host "   PGroup: Not Protected"
            Write-Host ""
            $script:notFoundReports["$($cluster.name):$($result.sourceInfo.name):$($result.name)"] = $True
        }
    }
}

# object not found
if(! $foundObject){
    if($returnJobName){
        return $null
    }
    Write-Host "$object not found"
}
