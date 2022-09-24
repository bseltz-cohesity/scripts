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
    [Parameter(Mandatory = $True)][string]$sourceServer,  # MongoDB registered source
    [Parameter(Mandatory = $True)][string]$sourceObject,  # MongoDB database/collection
    [Parameter()][string]$targetServer,                   # target MongoDB source
    [Parameter()][datetime]$recoverDate,                # recover from snapshot on or before this date 
    [Parameter()][int]$streams = 16,                    # concurrency streams
    [Parameter()][string]$suffix,                       # apply suffix to recovered object name
    [Parameter()][switch]$overwrite,                    # overwrite existing object
    [Parameter()][switch]$wait                          # wait for completion and report status
)

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

if($targetServer){
    $rootNodes = api get "protectionSources/rootNodes?environments=kMongoDB"
    $targetNode = $rootNodes | Where-Object {$_.protectionSource.name -eq $targetServer}
    if($null -eq $targetNode){
        Write-Host "targetServer $targetServer not found" -ForegroundColor Yellow
        exit 1
    }
}

$searchParams = @{
    "mongodbParams" = @{
        "mongoDBObjectTypes" = @(
            "MongoDatabases";
            "MongoCollections"
        );
        "searchString" = $sourceObject;
        "sourceIds" = @()
    };
    "objectType" = "MongoObjects";
    "protectionGroupIds" = @();
    "storageDomainIds" = @()
}

$search = api post -v2 data-protect/search/indexed-objects $searchParams

if($null -eq $search){
    Write-Host "Database/Collection $sourceObject not found" -ForegroundColor Yellow
    exit 1
}

$results = $search.mongoObjects | Where-Object {$_.sourceInfo.name -eq $sourceServer -and $_.name -eq $sourceObject}

if($null -eq $results){
    Write-Host "Database/Collection $sourceServer/$sourceObject not found" -ForegroundColor Yellow
    exit 1
}

$allSnapshots = @()
foreach($result in $results){
    $snapshots = api get -v2 "data-protect/objects/$($result.sourceInfo.sourceId)/protection-groups/$($result.protectionGroupId)/indexed-objects/snapshots?indexedObjectName=$($result.id)&includeIndexedSnapshotsOnly=true"
    if($null -ne $snapshots){
        $allSnapshots = @($allSnapshots + $snapshots.snapshots)
    }
}

if($recoverDate){
    $recoverDateUsecs = dateToUsecs ($recoverDate.AddMinutes(1))
    $snapshots = $allSnapshots | Sort-Object -Property snapshotTimestampUsecs -Descending | Where-Object snapshotTimestampUsecs -lt $recoverDateUsecs
    if($snapshots -and $snapshots.Count -gt 0){
        $snapshot = $snapshots[0]
        $snapshotId = $snapshot.objectSnapshotid
    }else{
        Write-Host "No snapshots available for $sourceServer/$sourceObject"
    }
}else{
    $snapshots = $allSnapshots | Sort-Object -Property snapshotTimestampUsecs -Descending
    $snapshot = $snapshots[0]
    $snapshotId = $snapshot.objectSnapshotid
}

$recoverDateString = (get-date).ToString('yyyy-MM-dd_hh-mm-ss')

$recoverParams = @{
    "name" = "Recover_MongoDB_$($sourceServer)_$($sourceObject)_$recoverDateString";
    "snapshotEnvironment" = "kMongoDB";
    "mongodbParams" = @{
        "recoveryAction" = "RecoverObjects";
        "recoverMongodbParams" = @{
            "overwrite" = $False;
            "concurrency" = $streams;
            "bandwidthMBPS" = $null;
            "snapshots" = @(
                @{
                    "snapshotId" = $snapshotId;
                    "objects" = @(
                        @{
                            "objectName" = $sourceObject
                        }
                    )
                }
            );
            "recoverTo" = $null;
            "suffix" = $null
        }
    }
}

if($targetServer){
    $recoverParams.mongodbParams.recoverMongodbParams.recoverTo = $targetNode.protectionSource.id
}

if($suffix){
    $recoverParams.mongodbParams.recoverMongodbParams.suffix = $suffix
}

if($overwrite){
    $recoverParams.mongodbParams.recoverMongodbParams.overwrite = $True
}

if($targetServer){
    Write-Host "Restoring $sourceServer/$sourceObject to $targetServer"
}else{
    Write-Host "Restoring $sourceServer/$sourceObject"
}

$recovery = api post -v2 data-protect/recoveries $recoverParams

# wait for restores to complete
$finishedStates = @('Canceled', 'Succeeded', 'Failed')
if(! $recovery.PSObject.Properties['id']){
    exit 1
}
if($wait){
    "Waiting for restore to complete..."
    do{
        Start-Sleep 30
        $recoveryTask = api get -v2 data-protect/recoveries/$($recovery.id)?includeTenants=true
        $status = $recoveryTask.status

    } until ($status -in $finishedStates)
    write-host "Restore task finished with status: $status"
    if($status -eq 'Failed'){
        if($recoveryTask.PSObject.Properties['messages'] -and $recoveryTask.messages.Count -gt 0){
            Write-Host "$($recoveryTask.messages[0])" -ForegroundColor Yellow
        }
    }
    if($status -eq 'Succeedded'){
        exit 0
    }else{
        exit 1
    }
}
exit 0
