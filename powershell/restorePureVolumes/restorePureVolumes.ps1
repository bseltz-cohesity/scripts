# usage: ./restorePureVolumes.ps1 -vip mycluster -username myusername -pureName mypure -volumeName myserver_lun1, myserver_lun2 -prefix 'restore-' -suffix '-0410'

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # Cohesity cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # Cohesity username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter(Mandatory = $True)][string]$pureName, # name of registered Pure array
    [Parameter()][array]$volumeName, # name(s) of volumes(s) to recover
    [Parameter()][string]$volumeList = $null, # file list of volumes to recover
    [Parameter(Mandatory = $True)][string]$prefix, # prefix for recovered volumes
    [Parameter(Mandatory = $True)][string]$suffix # suffix for recovered volumes
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# gather list of volumes to recover
$volumes = @()
foreach($v in $volumeName){
    $volumes += $v
}
if ($volumeList){
    if(Test-Path -Path $volumeList -PathType Leaf){
        $vlist = Get-Content $volumeList
        foreach($v in $vlist){
            $volumes += $v
        }
    }else{
        Write-Warning "Volume list $volumeList not found!"
        exit 1
    }
}

function searchVolume($pureName, $volumeName){
    $searchResult = api get "/searchvms?entityTypes=kPure&vmName=$volumeName"
    $volumeResult = $searchResult.vms | Where-Object {$_.vmDocument.objectName -eq $volumeName -and $_.vmDocument.registeredSource.displayName -eq $pureName}
    if(!$volumeResult){
        return $null
    }else{
        return $volumeResult.vmDocument[0]
    }
}

# validate all volumes exist before starting restores
foreach($volumeName in $volumes){
    $volume = searchVolume $pureName $volumeName
    if(!$volume){
        write-host "Volume $pureName/$volumeName not found!" -ForegroundColor Yellow
        exit 1
    }
}

# proceed with restores
foreach($volumeName in $volumes){
    $volume = searchVolume $pureName $volumeName
    if(!$volume){
        write-host "Volume $pureName/$volumeName not found!" -ForegroundColor Yellow
        exit 1
    }
    # restore params
    $restoreParams = @{
        "action"                    = 8;
        "name"                      = "Recover-pure_Apr_9_2020_2-06pm";
        "objects"                   = @(
            @{
                "jobId"          = $volume.objectId.jobId;
                "jobUid"         = $volume.objectId.jobUid;
                "entity"         = $volume.objectId.entity;
                "jobInstanceId"  = $volume.versions[0].instanceId.jobInstanceId;
                "attemptNum"     = $volume.versions[0].instanceId.attemptNum;
                "startTimeUsecs" = $volume.versions[0].instanceId.jobStartTimeUsecs
            }
        );
        "restoreParentSource"       = $volume.registeredSource;
        "renameRestoredObjectParam" = @{
            "prefix" = $prefix;
            "suffix" = $suffix
        }
    }
    "Restoring $pureName/$volumeName as $pureName/$prefix$volumeName$suffix"
    $null = api post /restore $restoreParams
}
