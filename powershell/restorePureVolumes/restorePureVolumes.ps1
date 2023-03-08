# usage: ./restorePureVolumes.ps1 -vip mycluster -username myusername -pureName mypure -volumeName myserver_lun1, myserver_lun2 -prefix 'restore-' -suffix '-0410'

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter(Mandatory = $True)][string]$pureName, # name of registered Pure array
    [Parameter(Mandatory = $True)][string]$jobName, # name of protection group
    [Parameter()][array]$volumeName, # name(s) of volumes(s) to recover
    [Parameter()][string]$volumeList = $null, # file list of volumes to recover
    [Parameter()][string]$prefix, # prefix for recovered volumes
    [Parameter()][string]$suffix, # suffix for recovered volumes
    [Parameter()][Int64]$runId,
    [Parameter()][switch]$showVersions
)

if(! $prefix -and ! $suffix){
    Write-Host "-prefix or -suffix required!" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

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
    $volumeResult = $searchResult.vms | Where-Object {$_.vmDocument.objectName -eq $volumeName -and $_.vmDocument.registeredSource.displayName -eq $pureName -and $_.vmDocument.jobName -eq $jobName}
    if(!$volumeResult){
        return $null
    }else{
        if($runId){
            $version = $volumeResult.vmDocument[0].versions | Where-Object {$_.instanceId.jobInstanceId -eq $runId}
            if(! $version){
                Write-Host "Volume $volumeName not present in runId $runId" -ForegroundColor Yellow
                exit
            }
        }
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
    # show versions
    if($showVersions){
        $volume.versions | Select-Object -Property @{label='runId'; expression={$_.instanceId.jobInstanceId}}, @{label='runDate'; expression={usecsToDate $_.instanceId.jobStartTimeUsecs}}
        exit 0
    }
}

$taskDate = Get-Date -UFormat "%b_%d_%Y_%H-%M"

# proceed with restores
foreach($volumeName in $volumes){
    $volume = searchVolume $pureName $volumeName
    if($runId){
        $version = $volume.versions | Where-Object {$_.instanceId.jobInstanceId -eq $runId}
    }else{
        $version = $volume.versions[0]
    }
    if(!$volume){
        write-host "Volume $pureName/$volumeName not found!" -ForegroundColor Yellow
        exit 1
    }
    
    # restore params
    $restoreParams = @{
        "action"                    = 8;
        "name"                      = "Recover-pure_$taskDate-$volumeName";
        "objects"                   = @(
            @{
                "jobId"          = $volume.objectId.jobId;
                "jobUid"         = $volume.objectId.jobUid;
                "entity"         = $volume.objectId.entity;
                "jobInstanceId"  = $version.instanceId.jobInstanceId;
                "attemptNum"     = $version.instanceId.attemptNum;
                "startTimeUsecs" = $version.instanceId.jobStartTimeUsecs
            }
        );
        "restoreParentSource"       = $volume.registeredSource;
        "renameRestoredObjectParam" = @{}
    }
    if($prefix -or $suffix){
        if($prefix){
            $restoreParams["renameRestoredObjectParam"]["prefix"] = $prefix
        }
        if($suffix){
            $restoreParams["renameRestoredObjectParam"]["suffix"] = $suffix
        }
    }
    "Restoring $pureName/$volumeName as $pureName/$prefix$volumeName$suffix"
    $null = api post /restore $restoreParams
}
