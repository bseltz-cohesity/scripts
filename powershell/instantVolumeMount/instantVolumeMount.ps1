
### usage: ./instantVolumeMount.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -sourceServer 'SQL2012' [ -targetServer 'SQLDEV01' ] [ -targetUsername 'ADuser' ] [ -targetPw 'myPassword' ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$sourceServer, #source server that was backed up
    [Parameter()][string]$targetServer = $sourceServer, #target server to mount the volumes to
    [Parameter()][string]$targetUsername = '', #credentials to ensure disks are online (optional, only needed if it's a VM with no agent)
    [Parameter()][string]$targetPw = '' #credentials to ensure disks are online (optional, only needed if it's a VM with no agent)
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### search for the source server
$searchResults = api get "/searchvms?entityTypes=kVMware&entityTypes=kPhysical&entityTypes=kHyperV&entityTypes=kHyperVVSS&entityTypes=kAcropolis&entityTypes=kView&vmName=$sourceServer"

### narrow the results to the correct server
$searchResults2 = $searchresults.vms | Where-Object { $_.vmDocument.objectName -ieq $sourceServer }

### if there are multiple results (e.g. old/new jobs?) select the one with the newest snapshot 
$latestResult = ($searchResults2 | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

if($latestResult -eq $null){
    write-host "Source Server $sourceServer Not Found" -foregroundcolor yellow
    exit
}

### get source and target entity info
$physicalEntities = api get "/entitiesOfType?environmentTypes=kVMware&environmentTypes=kPhysical&physicalEntityTypes=kHost&vmwareEntityTypes=kVCenter"
$virtualEntities = api get "/entitiesOfType?environmentTypes=kVMware&environmentTypes=kPhysical&isProtected=true&physicalEntityTypes=kHost&vmwareEntityTypes=kVirtualMachine" #&vmwareEntityTypes=kVCenter
$sourceEntity = (($physicalEntities + $virtualEntities) | Where-Object { $_.displayName -ieq $sourceServer })[0]
$targetEntity = (($physicalEntities + $virtualEntities) | Where-Object { $_.displayName -ieq $targetServer })[0]

if($sourceEntity -eq $null){
    Write-Host "Source Server $sourceServer Not Found" -ForegroundColor Yellow
    exit
}

if($targetEntity -eq $null){
    Write-Host "Target Server $targetServer Not Found" -ForegroundColor Yellow
    exit
}

$mountTask = @{
    'name' = 'myMountOperation';
    'objects' = @(
        @{
            'jobId' = $latestResult.vmDocument.objectId.jobId;
            'jobUid' = $latestResult.vmDocument.objectId.jobUid;
            'entity' = $sourceEntity;
            'jobInstanceId' = $latestResult.vmDocument.versions[0].instanceId.jobInstanceId;
            'startTimeUsecs' = $latestResult.vmDocument.versions[0].instanceId.jobStartTimeUsecs
        }
    );
    'mountVolumesParams' = @{
        'targetEntity' = $targetEntity;
        'vmwareParams' = @{
            'bringDisksOnline' = $true;
            'targetEntityCredentials' = @{
                'username' = $targetUsername;
                'password' = $targetPw;
            }
        }
    }
}

if( $targetEntity.parentId ){
    $mountTask['restoreParentSource'] = @{ 'id' = $targetEntity.parentId }
}

"mounting volumes to $targetServer..."
$result = api post /restore $mountTask
