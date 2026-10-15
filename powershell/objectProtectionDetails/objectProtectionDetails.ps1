### usage: ./objectProtectionDetails.ps1 -vip mycluster -username myusername -domain mydomain.net -objects vm1, vm2 [ -startDate 2019-10-01 ] [ -endDate 2019-11-01 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][array]$vip,
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][array]$clusterName,
    [Parameter()][switch]$exactMatchOnly,
    [Parameter(Mandatory = $True, ValueFromPipeline)][string[]]$objects
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

$script:foundObject = @{}
$script:objectProtected = @{}
$script:lastRuns = @{}
Write-Host ""

function findObjects(){
    $cluster = api get cluster
    $jobs = api get -v2 "data-protect/protection-groups?isActive=true&isDeleted=False"
    foreach($object in $objects){
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
            $script:foundObject[$object] = $True
            foreach($objectProtectionInfo in $result.objectProtectionInfos){
                foreach($protectionGroup in $objectProtectionInfo.protectionGroups){
                    if($protectionGroup.id -in @($jobs.protectionGroups.id)){
                        $script:objectProtected[$object] = $True
                        
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
        }
    }
}

# authentication / multi-cluster loop (see baseAuth-multi.ps1) =============================================
if(! $vip){
    $vip = @('helios.cohesity.com')
}

foreach($v in $vip){
    # authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt -quiet
    if(!$cohesity_api.authorized){
        Write-Host "$($v): authentication failed" -ForegroundColor Yellow
        continue
    }
    if(! $USING_HELIOS -and $useApiKey -and $password){
        # a cluster API key specified on the command line won't work for multiple clusters
        $password = $null
    }
    if($USING_HELIOS){
        if(! $clusterName){
            # inventory every Helios/MCM-managed cluster if none were specified on the command line
            $clusterName = @((heliosClusters).name)
        }
        foreach($c in $clusterName){
            $null = heliosCluster $c
            findObjects
        }
    }else{
        findObjects
    }
}

foreach($object in $objects){
    if($object -notin $script:foundObject.Keys){
        Write-Host "$object not found" -foregroundcolor Yellow
    }elseif($object -notin $script:objectProtected.Keys){
        Write-Host "$object not protected" -foregroundcolor Yellow
    }
}