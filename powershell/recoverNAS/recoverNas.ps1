### usage: ./recoverNas.ps1 -vip mycluster -username admin -shareName \\netapp1.mydomain.net\share1 -viewName share1

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$shareName, #sharename as listed in sources
    [Parameter(Mandatory = $True)][string]$viewName #name of the view to create
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### hard coding the qos selection
$qosSetting = 'TestAndDev High'

### find the VM to recover
$shares = api get restore/objects?search=$shareName

### narrow results to VMs with the exact name
$exactShares = $shares | Where-Object {$_.objectSnapshotInfo.snapshottedSource.name -ieq $shareName} #).objectSnapshotInfo[0]

### if there are multiple results (e.g. old/new jobs?) select the one with the newest snapshot 
$latestsnapshot = ($exactShares | sort-object -property @{Expression={$_.objectSnapshotInfo.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

### get entity
$entities = api get /entitiesOfType?environmentTypes=kNetapp`&environmentTypes=kGenericNas`&genericNasEntityTypes=kHost`&isProtected=true`&netappEntityTypes=kVolume
$entity = $entities | Where-Object { $_.displayName -ieq $shareName }

$nasRecovery = @{
    'action' = 10;
    'name' = "Recover-$shareName";
    'objects' = @(
        @{
            'jobId' = $latestsnapshot.objectSnapshotInfo[0].jobId;
            'jobUid' = @{
                'objectId' = $latestsnapshot.objectSnapshotInfo[0].jobUid.id;
                'clusterIncarnationId' = $latestsnapshot.objectSnapshotInfo[0].jobUid.clusterIncarnationId;
                'clusterId' = $latestsnapshot.objectSnapshotInfo[0].jobUid.clusterId
            };
            'entity' = $entity;
            'jobInstanceId' = $latestsnapshot.objectSnapshotInfo[0].versions[0].jobRunId;
            'attemptNum' = $latestsnapshot.objectSnapshotInfo[0].versions[0].attemptNumber;
            'startTimeUsecs' = $latestsnapshot.objectSnapshotInfo[0].versions[0].startedTimeUsecs
        }
    );
    'viewName' = $viewName;
    'viewParams' = @{
        'qos' = @{
            'principalName' = $qosSetting
        }
    }
}

"Recovering $shareName as view $viewName"
$result = api post /restore $nasRecovery
