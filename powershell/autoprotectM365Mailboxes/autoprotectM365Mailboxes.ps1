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
    [Parameter(Mandatory = $True)][string]$jobPrefix,  # name of the job to add VM to
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',  # storage domain you want the new job to write to
    [Parameter(Mandatory = $True)][string]$policyName,  # protection policy name
    [Parameter()][switch]$paused,  # pause future runs (new job only)
    [Parameter()][int]$incrementalSlaMinutes = 60,
    [Parameter()][int]$fullSlaMinutes = 120,
    [Parameter()][switch]$disableIndexing,
    [Parameter()][int]$maxObjectsPerJob = 4000,
    [Parameter(Mandatory = $True)][string]$sourceName,
    [Parameter()][int]$maxToProtect = 1000
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
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $helios -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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

$logFile = "$($jobPrefix)-log.txt"
$today = Get-Date -UFormat '%Y-%m-%d %H:%M:%S'
"`n==================================`nScript started $today`n==================================`n" | Out-File -FilePath $logFile -Append

# get the protectionJobs
$alljobs = (api get -v2 "data-protect/protection-groups?environments=kO365Exchange&isActive=true&isDeleted=false").protectionGroups | Where-Object {$_.office365Params.protectionTypes -eq 'kMailbox'}
$script:thesejobs = $alljobs | Sort-Object -Property name | Where-Object {$_.name -match $jobPrefix}

$rootSource = api get "protectionSources/rootNodes?environments=kO365" | Where-Object {$_.protectionSource.name -eq $sourceName}
if(! $rootSource){
    Write-Host "protection source $sourceName not found" -ForegroundColor Yellow
    exit 1
}

$rootSourceId = $rootSource[0].protectionSource.id

$policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $policyName
if(!$policy){
    Write-Host "Policy $policyName not found" -ForegroundColor Yellow
    exit 1
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

$newjob = @{
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
    "name" = "$($jobPrefix)001";
    "environment" = 'kO365Exchange';
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
            "kMailbox"
        );
        "outlookProtectionTypeParams" = $null;
        "oneDriveProtectionTypeParams" = $null;
        "publicFoldersProtectionTypeParams" = $null;
        "sourceId" = $rootSourceId;
        "sourceName" = $rootSource.protectionSource.name
    }
}

$newjob = $newjob | ConvertTo-JSON -Depth 99 | ConvertFrom-JSON

$script:nameIndex = @{}
$script:smtpIndex = @{}
$script:idIndex = @{}
$script:unprotectedIndex = @()
$script:protectedCount = 0
$script:unprotectedCount = 0
$script:protectedIndex = @()
$updateJobs = @{}
$newJobs = @{}

if($script:thesejobs){
    $script:protectedIndex = @($alljobs.office365Params.objects.id)
}

if(!$script:thesejobs){
    $thisNewJob = $newjob | ConvertTo-JSON -Depth 99 | ConvertFrom-JSON
    $script:thesejobs = @($thisNewJob)
    $newJobs[$thisNewJob.name] = $thisNewJob 
}

Write-Host "Finding mailboxes to autoprotect"

$foundObjects = 0
while($foundObjects -lt $maxToProtect){
    $search = api get -v2 "data-protect/search/objects?environments=kO365&o365ObjectTypes=kUser&sourceIds=$rootSourceId&count=500&searchString=*"
    foreach($obj in $search.objects | Sort-Object -Property name){
        foreach($objectProtectionInfo in $obj.objectProtectionInfos | Where-Object {$_.sourceId -eq $rootSourceId}){
            $objId = $objectProtectionInfo.objectId
            if($objId -and $objId -notin $script:protectedIndex){
                $foundObjects += 1
                $objectsToAdd = @($objectsToAdd + @{'name' = $obj.name; 'id' = $objectProtectionInfo.objectId})
                if($foundObjects -ge $maxToProtect){
                    break
                }
            }
        }
        if($foundObjects -ge $maxToProtect){
            break
        }
    }
    if($foundObjects -ge $maxToProtect){
        break
    }
    if(@($search.objects).Count -lt 500){
        break
    }
}   

Write-Host "*** $foundObjects mailboxes to autoprotect"

foreach($obj in $objectsToAdd){
    $objName = $obj.name
    $objId = $obj.id
    $added = $false
    foreach($job in $script:thesejobs){
        $protectedCount = @($job.office365Params.objects).Count
        if($protectedCount -ge $maxObjectsPerJob){
            continue
        }else{
            $job.office365Params.objects = @($job.office365Params.objects + @{'id' = $objId})
            "$($job.name) <- $objName" | Tee-Object -FilePath $logFile -Append
            if($job.name -notin $newJobs.Keys){
                $updateJobs[$job.name] = $job
            }
            $added = $True
        }
    }
    if($added -eq $false){
        $lastJobName = $script:thesejobs[-1].name
        $lastJobNum = $lastJobName.Substring($lastJobName.Length - 3)
        $newJobNum = [int]$lastJobNum + 1
        $newJobNum = "{0:D3}" -f $newJobNum
        $thisNewJob = $newjob | ConvertTo-JSON -Depth 99 | ConvertFrom-JSON
        $thisNewJob.name = "$($jobPrefix)$($newJobNum)"
        $newJobs[$thisNewJob.name] = $thisNewJob
        $script:thesejobs = @($thisNewJob)
        $thisNewJob.office365Params.objects
        $thisNewJob.office365Params.objects = @($thisNewJob.office365Params.objects + @{'id' = $objId})
        "$($thisNewJob.name) <- $objName" | Tee-Object -FilePath $logFile -Append
    }
}

foreach($job in $updateJobs.Values){
    foreach($obj in $job.office365Params.objects){
        $search = $search = api get -v2 "data-protect/search/objects?objectIds=$($obj.id)"
        if($search.objects.Count -eq 0){
            $job.office365Params.objects = @($job.office365Params.objects | Where-Object {$_.id -ne $obj.id})
        }
    }
    $null = api put -v2 data-protect/protection-groups/$($job.id) $job
}
foreach($job in $newJobs.Values){
    $null = api post -v2 data-protect/protection-groups/ $job
}
