### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][array]$site,  # names of sites to protect
    [Parameter()][string]$siteList = '',  # text file of sites to protect
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to add VM to
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',  # storage domain you want the new job to write to
    [Parameter()][string]$policyName,  # protection policy name
    [Parameter()][switch]$paused,  # pause future runs (new job only)
    [Parameter()][int]$incrementalSlaMinutes = 60,
    [Parameter()][int]$fullSlaMinutes = 120,
    [Parameter()][switch]$disableIndexing,
    [Parameter()][switch]$allSites,
    [Parameter()][int]$maxSitesPerJob = 5000,
    [Parameter()][string]$sourceName,
    [Parameter()][switch]$autoProtectRemaining,
    [Parameter()][switch]$dbg,
    [Parameter()][switch]$force
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
            exit 1
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit 1
    }
    return ($items | Sort-Object -Unique)
}

$sitesToAdd = @(gatherList -Param $site -FilePath $siteList -Name 'sites' -Required $False)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region

### select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit
}

$cluster = api get cluster
if($cluster.clusterSoftwareVersion -gt '6.8'){
    $environment = 'kO365Sharepoint'
}else{
    $environment = 'kO365'
}
if($cluster.clusterSoftwareVersion -lt '6.6'){
    $entityTypes = 'kUser,kGroup,kSite,kPublicFolder'
}else{
    $entityTypes = 'kUser,kGroup,kSite,kPublicFolder,kO365Exchange,kO365OneDrive,kO365Sharepoint'
}

# get the protectionJob
$jobs = (api get -v2 "data-protect/protection-groups?environments=kO365&isActive=true&isDeleted=false").protectionGroups | Where-Object {$_.office365Params.protectionTypes -eq 'kSharePoint'}
$job = $jobs | Where-Object {$_.name -eq $jobName}
$otherJobs = $jobs | Where-Object {$_.name -ne $jobName}

if($job){

    # existing protection job
    $newJob = $false
    if($autoProtectRemaining){
        $job.office365Params.excludeObjectIds = $otherJobs.office365Params.objects.id
        "Updating protection job $($job.name)"
        $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
        exit
    }

}else{

    # new protection group
    $newJob = $True

    if($paused){
        $isPaused = $True
    }else{
        $isPaused = $false
    }

    if($disableIndexing){
        $enableIndexing = $false
    }else{
        $enableIndexing = $True
    }

    # get policy
    if(!$policyName){
        Write-Host "-policyName required" -ForegroundColor Yellow
        exit 1
    }else{
        $policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $policyName
        if(!$policy){
            Write-Host "Policy $policyName not found" -ForegroundColor Yellow
            exit 1
        }
    }
    
    # get storageDomain
    $viewBoxes = api get viewBoxes
    if($viewBoxes -is [array]){
            $viewBox = $viewBoxes | Where-Object { $_.name -ieq $storageDomainName }
            if (!$viewBox) { 
                write-host "Storage domain $storageDomainName not Found" -ForegroundColor Yellow
                exit 1
            }
    }else{
        $viewBox = $viewBoxes[0]
    }

    # parse startTime
    $hour, $minute = $startTime.split(':')
    $tempInt = ''
    if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
        Write-Host "Please provide a valid start time" -ForegroundColor Yellow
        exit 1
    }

    $job = @{
        "policyId" = $policy.id;
        "isPaused" = $isPaused;
        "startTime" = @{
            "hour"     = [int]$hour;
            "minute"   = [int]$minute;
            "timeZone" = $timeZone
        };
        "priority" = "kMedium";
        "sla" = @(
            @{
                "backupRunType" = "kFull";
                "slaMinutes" = $fullSlaMinutes
            };
            @{
                "backupRunType" = "kIncremental";
                "slaMinutes" = $incrementalSlaMinutes
            }
        );
        "qosPolicy" = "kBackupHDD";
        "abortInBlackouts" = $false;
        "storageDomainId" = $viewBox.id;
        "name" = $jobName;
        "environment" = $environment;
        "description" = "";
        "alertPolicy" = @{
            "backupRunStatus" = @(
                "kFailure"
            );
            "alertTargets" = @()
        };
        "office365Params" = @{
            "indexingPolicy" = @{
                "enableIndexing" = $enableIndexing;
                "includePaths" = @(
                    "/"
                );
                "excludePaths" = @()
            };
            "objects" = @();
            "excludeObjectIds" = @();
            "protectionTypes" = @(
                "kSharePoint"
            );
            "outlookProtectionTypeParams" = $null;
            "oneDriveProtectionTypeParams" = $null;
            "publicFoldersProtectionTypeParams" = $null
        }
    }

    $job = $job | ConvertTo-JSON -Depth 99 | ConvertFrom-JSON
}

if($job.office365Params.PSObject.Properties['sourceId']){
    $sourceId = $job.office365Params.sourceId
    $rootSource = api get "protectionSources/rootNodes?environments=kO365&id=$sourceId"
}else{
    if(! $sourceName){
        Write-Host "-sourceName required" -ForegroundColor Yellow
        exit
    }
    $rootSource = api get "protectionSources/rootNodes?environments=kO365" | Where-Object {$_.protectionSource.name -eq $sourceName}
}
if(! $rootSource){
    Write-Host "protection source $sourceName not found" -ForegroundColor Yellow
    exit
}

$source = api get "protectionSources?id=$($rootSource.protectionSource.id)&excludeOffice365Types=$entityTypes&allUnderHierarchy=false"
$sitesNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Sites'}
if(!$sitesNode){
    Write-Host "Source $sourceName is not configured for O365 Sites" -ForegroundColor Yellow
    exit
}

Write-Host "Discovering sites..."

$nameIndex = @{}
$webUrlIndex = @{}
$unprotectedIndex = @()
$protectedIndex = @()
$nodeIdIndex = @()
$lastCursor = 0

$sites = api get "protectionSources?pageSize=50000&nodeId=$($sitesNode.protectionSource.id)&id=$($sitesNode.protectionSource.id)&allUnderHierarchy=false&useCachedData=false"
$cursor = $sites.entityPaginationParameters.beforeCursorEntityId

# enumerate sites
while(1){
    foreach($node in $sites.nodes){
        $nodeIdIndex = @($nodeIdIndex + $node.protectionSource.id)
        $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
        if($node.protectionSource.office365ProtectionSource.PSObject.Properties['webUrl']){
            $webUrlIndex["$([string]$node.protectionSource.office365ProtectionSource.webUrl)"] = $node.protectionSource.id
        }
        if($node.protectedSourcesSummary[0].leavesCount){
            $protectedIndex = @($protectedIndex + $node.protectionSource.id)
        }else{
            $unprotectedIndex = @($unprotectedIndex + $node.protectionSource.id)
        }
        $lastCursor = $node.protectionSource.id
    }
    if($cursor){
        $sites = api get "protectionSources?pageSize=50000&nodeId=$($sitesNode.protectionSource.id)&id=$($sitesNode.protectionSource.id)&allUnderHierarchy=false&useCachedData=false&afterCursorEntityId=$cursor"
        $cursor = $sites.entityPaginationParameters.beforeCursorEntityId
    }else{
        break
    }
    # patch for 6.8.1
    if($sites.nodes -eq $null){
        if($cursor -gt $lastCursor){
            $node = api get protectionSources?id=$cursor
            $nodeIdIndex = @($nodeIdIndex + $node.protectionSource.id)
            $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
            if($node.protectionSource.office365ProtectionSource.PSObject.Properties['webUrl']){
                $webUrlIndex["$([string]$node.protectionSource.office365ProtectionSource.webUrl)"] = $node.protectionSource.id
            }
            if($node.protectedSourcesSummary[0].leavesCount){
                $protectedIndex = @($protectedIndex + $node.protectionSource.id)
            }else{
                $unprotectedIndex = @($unprotectedIndex + $node.protectionSource.id)
            }
            $lastCursor = $node.protectionSource.id
        }
    }
    if($cursor -eq $lastCursor){
        break
    }
}

$nodeIdIndex = @($nodeIdIndex | Sort-Object -Unique)
Write-Host "$($nodeIdIndex.Count) sites discovered ($($protectedIndex.Count) protected, $($unprotectedIndex.Count) unprotected)"

if($autoProtectRemaining){
    if($unprotectedIndex.Count -gt $maxSitesPerJob){
        Write-Host "There are $($unprotectedIndex.Count) sites to protect, which is more than the maximum allowed ($maxSitesPerJob)" -ForegroundColor Yellow
        exit
    }
    if(!($job.office365Params.objects | Where-Object {$_.id -eq $sitesNode.protectionSource.id})){
        $job.office365Params.objects = @($job.office365Params.objects + @{'id' = $sitesNode.protectionSource.id})
    }
    if(! $job.office365Params.PSObject.Properties['excludeObjectIds']){
        setApiProperty -object $job.office365Params -name 'excludeObjectIds' -value @()
    }
    $job.office365Params.excludeObjectIds = $protectedIndex
}elseif($allSites){
    $sitesAdded = 0
    if($force){
        $autoprotectedIndex = $protectedIndex | Where-Object {$_ -notin $jobs.office365Params.objects.id}
        foreach($siteId in $autoprotectedIndex){
            if($job.office365Params.objects.Count -ge $maxsitesPerJob){
                break
            }
            $job.office365Params.objects = @($job.office365Params.objects + @{'id' = $siteId})
            $sitesAdded += 1
        }
    }else{
        if($unprotectedIndex.Count -eq 0){
            Write-Host "All sites are protected" -ForegroundColor Green
            exit
        }
    }
    foreach($siteId in $unprotectedIndex){
        if($job.office365Params.objects.Count -ge $maxSitesPerJob){
            break
        }
        $job.office365Params.objects = @($job.office365Params.objects + @{'id' = $siteId})
        $sitesAdded += 1
    }
    if($sitesAdded -eq 0){
        Write-Host "Job already has the maximum number of sites protected" -ForegroundColor Yellow
        exit
    }else{
        Write-Host "$sitesAdded added"
    }
}else{
    if($sitesToAdd.Count -eq 0){
        Write-Host "No sites specified to add"
        exit
    }else{
        $sitesAdded = 0
        foreach($siteName in $sitesToAdd){
            if($job.office365Params.objects.Count -ge $maxSitesPerJob){
                Write-Host "Job already has the maximum number of sites protected"
                continue
            }
            if($siteName -ne '' -and $null -ne $siteName){
                if($nameIndex.ContainsKey($siteName) -or $webUrlIndex.ContainsKey("$siteName")){
                    if($nameIndex.ContainsKey($siteName)){
                        $siteId = $nameIndex[$siteName]
                    }else{
                        $siteId = $webUrlIndex["$siteName"]
                    }
                    if($siteId -in $protectedIndex){
                        Write-Host "$siteName already protected" -ForegroundColor Green
                    }else{
                        Write-Host "adding $siteName"
                        $job.office365Params.objects = @($job.office365Params.objects + @{'id' = $siteId})
                        $sitesAdded += 1
                    }
                }else{
                    Write-Host "$siteName not found" -ForegroundColor Yellow
                }
            }
        }
    }
    if($sitesAdded -eq 0){
        Write-Host "No sites added" -ForegroundColor Yellow
        exit
    }
}

if($newJob){
    "Creating protection job $jobName"
    $null = api post -v2 "data-protect/protection-groups" $job
}else{
    "Updating protection job $($job.name)"
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}
