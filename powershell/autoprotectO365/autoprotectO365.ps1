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
    [Parameter(Mandatory = $True)][string]$jobPrefix,  # name of the job to add VM to
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',  # storage domain you want the new job to write to
    [Parameter(Mandatory = $True)][string]$policyName,  # protection policy name
    [Parameter()][switch]$paused,  # pause future runs (new job only)
    [Parameter()][int]$incrementalSlaMinutes = 60,
    [Parameter()][int]$fullSlaMinutes = 120,
    [Parameter()][switch]$disableIndexing,
    [Parameter()][switch]$createFirstJob,
    [Parameter()][string]$firstJobNum = '001',
    [Parameter()][int]$maxObjectsPerJob = 2000,
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter()][ValidateSet('mailbox','onedrive','sites','teams','publicfolders')][string]$objectType = 'mailbox'
)

$queryParam = ''
if($objectType -eq 'mailbox'){
    $objectString = 'Mailboxes'
    $nodeString = 'users'
    $objectKtype = 'kMailbox'
    $environment68 = 'kO365Exchange'
    $queryParam = '&hasValidMailbox=true&hasValidOnedrive=false'
}elseif($objectType -eq 'onedrive'){
    $objectString = 'OneDrives'
    $nodeString = 'users'
    $objectKtype = 'kOneDrive'
    $environment68 = 'kO365OneDrive'
    $queryParam = '&hasValidOnedrive=true&hasValidMailbox=false'
}elseif($objectType -eq 'sites'){
    $objectString = 'Sites'
    $nodeString = 'Sites'
    $objectKtype = 'kSharePoint'
    $environment68 = 'kO365Sharepoint'
}elseif($objectType -eq 'teams'){
    $objectString = 'Teams'
    $nodeString = 'Teams'
    $objectKtype = 'kTeams'
    $environment68 = 'kO365Teams'
}elseif($objectType -eq 'publicfolders'){
    $objectString = 'PublicFolders'
    $nodeString = 'PublicFolders'
    $objectKtype = 'kPublicFolders'
    $environment68 = 'kO365PublicFolders'
}else{
    Write-Host "Invalid objectType" -ForegroundColor Yellow
    exit
}

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

$logFile = "$($jobPrefix)-log.txt"
$today = Get-Date -UFormat '%Y-%m-%d %H:%M:%S'

# get the protectionJobs
$jobs = (api get -v2 "data-protect/protection-groups?environments=kO365&isActive=true&isDeleted=false").protectionGroups | Where-Object {$_.office365Params.protectionTypes -eq $objectKtype}
$jobs = $jobs | Sort-Object -Property name | Where-Object {$_.name -match $jobPrefix}
if($jobs){
    "`n==================================`nScript started $today`n==================================`n" | Out-File -FilePath $logFile -Append
}
if(!$jobs -and !$createFirstJob){
    Write-Host "No jobs with specified prefix found" -ForegroundColor Yellow
    Write-Host "Please use -createFirstJob -firstJob 1 (or 01 or 001)" -ForegroundColor Yellow
    exit
}

$cluster = api get cluster
if($cluster.clusterSoftwareVersion -gt '6.8'){
    $environment = $environment68
}else{
    $environment = 'kO365'
}
if($cluster.clusterSoftwareVersion -lt '6.6'){
    $entityTypes = 'kMailbox,kUser,kGroup,kSite,kPublicFolder'
}else{
    $entityTypes = 'kMailbox,kUser,kGroup,kSite,kPublicFolder,kO365Exchange,kO365OneDrive,kO365Sharepoint'
}

$rootSource = api get "protectionSources/rootNodes?environments=kO365" | Where-Object {$_.protectionSource.name -eq $sourceName}
if(! $rootSource){
    Write-Host "protection source $sourceName not found" -ForegroundColor Yellow
    exit
}

$source = api get "protectionSources?id=$($rootSource.protectionSource.id)&excludeOffice365Types=$entityTypes&allUnderHierarchy=false"
$objectsNode = $source.nodes | Where-Object {$_.protectionSource.name -eq $nodeString}
if(!$objectsNode){
    Write-Host "Source $sourceName is not configured for O365 $objectString" -ForegroundColor Yellow
    exit
}

Write-Host "Discovering $objectString..."

$nameIndex = @{}
$smtpIndex = @{}
$unprotectedIndex = @()
$protectedIndex = @()
$nodeIdIndex = @()
$lastCursor = 0

$jobs = (api get -v2 "data-protect/protection-groups?environments=kO365&isActive=true&isDeleted=false").protectionGroups | Where-Object {$_.office365Params.protectionTypes -eq $objectKtype}

$protectedIndex = @($jobs.office365Params.objects.id | Where-Object {$_ -ne $null})
$unprotectedIndex = @()
$unprotectedName = @{}

$objects = api get "protectionSources?pageSize=50000&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false$($queryParam)&useCachedData=false"
$cursor = $objects.entityPaginationParameters.beforeCursorEntityId
if($objectsNode.protectionSource.id -in $protectedIndex){
    $autoProtected = $True
}

# enumerate objects
while(1){
    foreach($node in $objects.nodes){
        $nodeIdIndex = @($nodeIdIndex + $node.protectionSource.id)
        $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
        if($node.protectionSource.office365ProtectionSource.PSObject.Properties['primarySMTPAddress']){
            $smtpIndex[$node.protectionSource.office365ProtectionSource.primarySMTPAddress] = $node.protectionSource.id
        }
        if($autoProtected -eq $True -and $node.protectionSource.id -notin $unprotectedIndex){
            $protectedIndex = @($protectedIndex + $node.protectionSource.id)
        }
        if($autoProtected -ne $True -and $node.protectionSource.id -notin $protectedIndex){
            $unprotectedIndex = @($unprotectedIndex + $node.protectionSource.id)
            $unprotectedName["$($node.protectionSource.id)"] = $node.protectionSource.name
        }
        $lastCursor = $node.protectionSource.id
    }
    if($cursor){
        $objects = api get "protectionSources?pageSize=50000&nodeId=$($objectsNode.protectionSource.id)&id=$($objectsNode.protectionSource.id)&allUnderHierarchy=false$($queryParam)&useCachedData=false&afterCursorEntityId=$cursor"
        $cursor = $objects.entityPaginationParameters.beforeCursorEntityId
    }else{
        break
    }
    # patch for 6.8.1
    if($objects.nodes -eq $null){
        if($cursor -gt $lastCursor){
            $node = api get "protectionSources?id=$cursor$($queryParam)"
            $nodeIdIndex = @($nodeIdIndex + $node.protectionSource.id)
            $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
            if($node.protectionSource.office365ProtectionSource.PSObject.Properties['primarySMTPAddress']){
                $smtpIndex[$node.protectionSource.office365ProtectionSource.primarySMTPAddress] = $node.protectionSource.id
            }
            if($autoProtected -eq $True -and $node.protectionSource.id -notin $unprotectedIndex){
                $protectedIndex = @($protectedIndex + $node.protectionSource.id)
            }
            if($autoProtected -ne $True -and $node.protectionSource.id -notin $protectedIndex){
                $unprotectedIndex = @($unprotectedIndex + $node.protectionSource.id)
                $unprotectedName["$($node.protectionSource.id)"] = $node.protectionSource.name
            }
            $lastCursor = $node.protectionSource.id
        }
    }
    if($cursor -eq $lastCursor){
        break
    }
}

$nodeIdIndex = @($nodeIdIndex | Sort-Object -Unique)

$objectCount = $nodeIdIndex.Count
$protectedCount = $protectedIndex.Count
$unprotectedCount = $unprotectedIndex.Count

Write-Host "$($nodeIdIndex.Count) $objectString discovered ($($protectedIndex.Count) protected, $($unprotectedIndex.Count) unprotected)"

$allObjectsAdded = 0

while($unprotectedCount -gt 0){

    # get the protectionJob
    $jobs = (api get -v2 "data-protect/protection-groups?environments=kO365&isActive=true&isDeleted=false").protectionGroups | Where-Object {$_.office365Params.protectionTypes -eq $objectKtype}

    $jobs = $jobs | Sort-Object -Property name | Where-Object {$_.name -match $jobPrefix}
    if($jobs){
        $job = $jobs[-1]
        $currentJobNum =  $job.name -replace '.*(?:\D|^)(\d+)','$1'
        if($job.office365Params.objects.Count -ge $maxObjectsPerJob){
            $currentJobNum = "{0:d$($currentJobNum.Length)}" -f ([int]$currentJobNum + 1)
            $jobName = "{0}{1}" -f $jobPrefix, $currentJobNum
            Write-Host "New job name is $jobName"
            "  Creating job $jobName" | Out-File -FilePath $logFile -Append
            $job = $null
        }else{
            Write-Host "Working on $($job.name)"
            "  Using job $($job.name)" | Out-File -FilePath $logFile -Append
        }
    }else{
        $jobName = "{0}{1}" -f $jobPrefix, $firstJobNum
        "==================================`nScript started $today`n==================================`n" | Out-File -FilePath $logFile
        "  Creating job $jobName" | Out-File -FilePath $logFile -Append
    }

    if($job){

        # existing protection job
        $newJob = $false

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
                    $objectKtype
                );
                "outlookProtectionTypeParams" = $null;
                "oneDriveProtectionTypeParams" = $null;
                "publicFoldersProtectionTypeParams" = $null
            }
        }

        $job = $job | ConvertTo-JSON -Depth 99 | ConvertFrom-JSON
    }

    $objectsAdded = 0

    if($unprotectedIndex.Count -eq 0){
        Write-Host "All $objectString are protected" -ForegroundColor Green
        exit
    }

    foreach($objectId in $unprotectedIndex){
        if($job.office365Params.objects.Count -lt $maxObjectsPerJob){
            $job.office365Params.objects = @($job.office365Params.objects + @{'id' = $objectId})
            "    + $($unprotectedName["$($objectId)"])" | Out-File -FilePath $logFile -Append
            $protectedIndex = @($protectedIndex + $objectId)
            $objectsAdded += 1
            $allObjectsAdded += 1
            $protectedCount += 1
            $unprotectedCount -= 1
        }
    }
    if($objectsAdded -eq 0 -and $job.office365Params.objects.Count -ge $maxObjectsPerJob){
        Write-Host "Job already has the maximum number of $objectString protected" -ForegroundColor Yellow
    }else{
        Write-Host "$objectsAdded added"
    }

    if($newJob){
        "Creating protection job $jobName"
        $null = api post -v2 "data-protect/protection-groups" $job
    }else{
        "Updating protection job $($job.name)"
        $job.office365Params.objects = @($job.office365Params.objects | Where-Object {$_.id -in $nodeIdIndex})
        $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
    }

    $unprotectedIndex = @($unprotectedIndex | Where-Object {$_ -notin $protectedIndex})
}
if($allObjectsAdded -gt 0){
    "    $allObjectsAdded $objectString added`n" | Out-File -FilePath $logFile -Append
}
"$($objectString): {0}  Protected: {1}  Unprotected: {2}" -f $objectCount, $protectedCount, $unprotectedCount | Tee-Object -FilePath $logFile -Append
