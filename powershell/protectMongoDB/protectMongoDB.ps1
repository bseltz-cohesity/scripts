### usage: ./protectVMs.ps1 -vip bseltzve01 -username admin -jobName 'vm backup' -vmName mongodb

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',          # username (local or AD)
    [Parameter()][string]$domain = 'local',             # local or AD domain
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][switch]$noPrompt,                     # don't prompt for password
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][switch]$emailMfaCode,                 # send mfa code via email
    [Parameter()][string]$clusterName = $null,          # cluster to connect to via helios/mcm
    [Parameter()][array]$objectName,  # name of databases to protect
    [Parameter()][string]$objectList = '',  # text file of databases to protect
    [Parameter()][switch]$exclude,  # autoprotect source (and use objectName. objectList as exclusions)
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to add VM to
    [Parameter(Mandatory = $True)][string]$sourceName,  # vcenter source name
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/New_York', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalSlaMinutes = 60,  # incremental SLA minutes
    [Parameter()][int]$fullSlaMinutes = 120,  # full SLA minutes
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',  # storage domain you want the new job to write to
    [Parameter()][string]$policyName,  # protection policy name
    [Parameter()][switch]$paused,  # pause future runs (new job only)
    [Parameter()][ValidateSet('kBackupHDD', 'kBackupSSD', 'kBackupAll')][string]$qosPolicy = 'kBackupHDD',
    [Parameter()][int]$streams = 16
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


$objectNames = @(gatherList -Param $objectName -FilePath $objectList -Name 'objects' -Required $false)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -noPromptForPassword $noPrompt

if($USING_HELIOS){
    if($clusterName){
        heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

# get protection source
$rootNodes = api get "protectionSources/registrationInfo?pruneNonCriticalInfo=true&includeEntityPermissionInfo=true&includeApplicationsTreeInfo=false&environments=kMongoDB"
$rootNode = $rootNodes.rootNodes | Where-Object {$_.rootNode.name -eq $sourceName}
if(!$rootNode){
    Write-Host "$sourceName not found!" -ForegroundColor Yellow
    exit
}
$source = api get protectionSources?id=$($rootNode.rootNode.id)
$objectIds = @{}
foreach($database in $source.nodes){
    $objectIds["$($database.protectionSource.name)"] = $database.protectionSource.id
    foreach($collection in $database.nodes){
        $objectIds["$($database.protectionSource.name).$($collection.protectionSource.name)"] = $collection.protectionSource.id
    }
}

# get the protectionJob
$job = (api get -v2 "data-protect/protection-groups").protectionGroups | Where-Object {$_.name -eq $jobName}

if($job){
    # existing protection job
    $newJob = $false
    if($job.mongodbParams.sourceId -ne $rootNode.rootNode.id){
        Write-Host "Job $jobName does not protect $sourceName" -ForegroundColor Yellow
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

    # get policy
    if(!$policyName){
        Write-Host "-policyName required" -ForegroundColor Yellow
        exit
    }else{
        $policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $policyName
        if(!$policy){
            Write-Host "Policy $policyName not found" -ForegroundColor Yellow
            exit
        }
    }
    
    # get storageDomain
    $viewBoxes = api get viewBoxes
    if($viewBoxes -is [array]){
            $viewBox = $viewBoxes | Where-Object { $_.name -ieq $storageDomainName }
            if (!$viewBox) { 
                write-host "Storage domain $storageDomainName not Found" -ForegroundColor Yellow
                exit
            }
    }else{
        $viewBox = $viewBoxes[0]
    }

    # parse startTime
    $hour, $minute = $startTime.split(':')
    $tempInt = ''
    if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
        Write-Host "Please provide a valid start time" -ForegroundColor Yellow
        exit
    }

    $job = @{
        "policyId" = $policy.id;
        "startTime" = @{
            "hour" = [int]$hour;
            "minute" = [int]$minute;
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
        "qosPolicy" = $qosPolicy;
        "storageDomainId" = $viewBox.id;
        "name" = $jobName;
        "environment" = "kMongoDB";
        "isPaused" = $isPaused;
        "description" = "";
        "alertPolicy" = @{
            "backupRunStatus" = @(
                "kFailure"
            );
            "alertTargets" = @()
        };
        "mongodbParams" = @{
            "objects" = @();
            "concurrency" = $streams;
            "excludeObjectIds" = @();
            "bandwidthMBPS" = $null;
            "sourceName" = $rootNode.rootNode.name;
            "sourceId" = $rootNode.rootNode.id
        }
    }
}

if($newJob){
    "Creating protection job $jobName"
}else{
    "Updating protection job $($job.name)"
}

if($objectNames.Count -eq 0 -or $exclude){
    Write-Host "protecting $sourceName"
    $job.mongodbParams.objects = @(
        @{
            "id" = $rootNode.rootNode.id
        }
    )
}

foreach($oName in $objectNames){
    if($oName -in $objectIds.Keys){
        if($exclude){
            $job.mongodbParams.excludeObjectIds = @($job.mongodbParams.excludeObjectIds + $objectIds[$oName])
            Write-Host "excluding $oName"
        }else{
            $existingObject = $job.mongodbParams.objects | Where-Object id -eq $objectIds[$oName]
            if(!$existingObject){
                $job.mongodbParams.objects = @($job.mongodbParams.objects + @{ "id" = $objectIds[$oName]})
                Write-Host "protecting $oName"
            }else{
                Write-Host "$oName already protected"
            }
        }
    }else{
        Write-Host "$oName not found" -ForegroundColor Yellow
    }
}

if($newJob){
    $null = api post -v2 "data-protect/protection-groups" $job
}else{
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}
