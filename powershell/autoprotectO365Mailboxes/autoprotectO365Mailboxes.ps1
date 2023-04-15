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
    [Parameter()][int]$maxMailboxesPerJob = 5000,
    [Parameter(Mandatory = $True)][string]$sourceName
)

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
    $environment = 'kO365Exchange'
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
$mailboxesNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'users'}
if(!$mailboxesNode){
    Write-Host "Source $sourceName is not configured for O365 mailboxes" -ForegroundColor Yellow
    exit
}

Write-Host "Discovering mailboxes..."

$nameIndex = @{}
$smtpIndex = @{}
$unprotectedIndex = @()
$protectedIndex = @()
$nodeIdIndex = @()
$lastCursor = 0

$jobs = (api get -v2 "data-protect/protection-groups?environments=kO365&isActive=true&isDeleted=false").protectionGroups | Where-Object {$_.office365Params.protectionTypes -eq 'kMailbox'}

$protectedIndex = @($jobs.office365Params.objects.id | Where-Object {$_ -ne $null})
$unprotectedIndex = @($jobs.office365Params.excludeObjectIds | Where-Object {$_ -ne $null -and $_ -notin $protectedIndex})

$mailboxes = api get "protectionSources?pageSize=50000&nodeId=$($mailboxesNode.protectionSource.id)&id=$($mailboxesNode.protectionSource.id)&allUnderHierarchy=false&hasValidMailbox=true&useCachedData=false"
$cursor = $mailboxes.entityPaginationParameters.beforeCursorEntityId
if($mailboxesNode.protectionSource.id -in $protectedIndex){
    $autoProtected = $True
}

# enumerate mailboxes
while(1){
    foreach($node in $mailboxes.nodes){
        $nodeIdIndex = @($nodeIdIndex + $node.protectionSource.id)
        $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
        $smtpIndex[$node.protectionSource.office365ProtectionSource.primarySMTPAddress] = $node.protectionSource.id
        if($autoProtected -eq $True -and $node.protectionSource.id -notin $unprotectedIndex){
            $protectedIndex = @($protectedIndex + $node.protectionSource.id)
        }
        if($autoProtected -ne $True -and $node.protectionSource.id -notin $protectedIndex){
            $unprotectedIndex = @($unprotectedIndex + $node.protectionSource.id)
        }
        $lastCursor = $node.protectionSource.id
    }
    if($cursor){
        $mailboxes = api get "protectionSources?pageSize=50000&nodeId=$($mailboxesNode.protectionSource.id)&id=$($mailboxesNode.protectionSource.id)&allUnderHierarchy=false&hasValidMailbox=true&useCachedData=false&afterCursorEntityId=$cursor"
        $cursor = $mailboxes.entityPaginationParameters.beforeCursorEntityId
    }else{
        break
    }
    # patch for 6.8.1
    if($mailboxes.nodes -eq $null){
        if($cursor -gt $lastCursor){
            $node = api get protectionSources?id=$cursor
            $nodeIdIndex = @($nodeIdIndex + $node.protectionSource.id)
            $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
            $smtpIndex[$node.protectionSource.office365ProtectionSource.primarySMTPAddress] = $node.protectionSource.id
            if($autoProtected -eq $True -and $node.protectionSource.id -notin $unprotectedIndex){
                $protectedIndex = @($protectedIndex + $node.protectionSource.id)
            }
            if($autoProtected -ne $True -and $node.protectionSource.id -notin $protectedIndex){
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

$mailboxCount = $nodeIdIndex.Count
$protectedCount = $protectedIndex.Count
$unprotectedCount = $unprotectedIndex.Count

Write-Host "$($nodeIdIndex.Count) mailboxes discovered ($($protectedIndex.Count) protected, $($unprotectedIndex.Count) unprotected)"

while($unprotectedCount -gt 0){
    # get the protectionJob
    $jobs = (api get -v2 "data-protect/protection-groups?environments=kO365&isActive=true&isDeleted=false").protectionGroups | Where-Object {$_.office365Params.protectionTypes -eq 'kMailbox'}

    $jobs = $jobs | Sort-Object -Property name | Where-Object {$_.name -match $jobPrefix}
    if($jobs){
        $job = $jobs[-1]
        $currentJobNum =  $job.name  -replace '.*(?:\D|^)(\d+)','$1'
        if($job.office365Params.objects.Count -ge $maxmailboxesPerJob){
            $currentJobNum = [int]$currentJobNum + 1
            $jobName = "{0}{1}" -f $jobPrefix, $currentJobNum
            Write-Host "New job name is $jobName"
            $job = $null
        }else{
            Write-Host "Working on $($job.name)"
        }
    }else{
        $jobName = "{0}{1}" -f $jobPrefix, '1'
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
                    "kMailbox"
                );
                "outlookProtectionTypeParams" = $null;
                "oneDriveProtectionTypeParams" = $null;
                "publicFoldersProtectionTypeParams" = $null
            }
        }

        $job = $job | ConvertTo-JSON -Depth 99 | ConvertFrom-JSON
    }

    $mailboxesAdded = 0

    if($unprotectedIndex.Count -eq 0){
        Write-Host "All mailboxes are protected" -ForegroundColor Green
        exit
    }

    foreach($mailboxId in $unprotectedIndex){
        if($job.office365Params.objects.Count -lt $maxmailboxesPerJob){
            $job.office365Params.objects = @($job.office365Params.objects + @{'id' = $mailboxId})
            $protectedIndex = @($protectedIndex + $mailboxId)
            $mailboxesAdded += 1
            $protectedCount += 1
            $unprotectedCount -= 1
        }
    }
    if($mailboxesAdded -eq 0 -and $job.office365Params.objects.Count -ge $maxMailboxesPerJob){
        Write-Host "Job already has the maximum number of mailboxes protected" -ForegroundColor Yellow
    }else{
        Write-Host "$mailboxesAdded added"
    }

    if($newJob){
        "Creating protection job $jobName"
        $null = api post -v2 "data-protect/protection-groups" $job
    }else{
        "Updating protection job $($job.name)"
        $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
    }

    $unprotectedIndex = @($unprotectedIndex | Where-Object {$_ -notin $protectedIndex})
}

"Mailboxes: {0}  Protected: {1}  Unprotected: {2}" -f $mailboxCount, $protectedCount, $unprotectedCount
