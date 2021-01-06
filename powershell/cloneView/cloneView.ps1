### usage: ./cloneView.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -viewName 'SMBShare' -newName 'Cloned-SMBShare'

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$viewName,
    [Parameter(Mandatory = $True)][string]$newName,
    [Parameter()][string]$vaultName = $null,
    [Parameter()][string]$backupDate = $null,
    [Parameter()][switch]$showVersions,
    [Parameter()][switch]$showDates
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### search for view to clone
$searchResults = api get /searchvms?entityTypes=kView`&vmName=$viewName
$viewResult = $searchResults.vms | Where-Object { $_.vmDocument.objectName -ieq $viewName }

if ($viewResult) {

    $doc = $viewResult[0].vmDocument
    $versions = $doc.versions

    if($vaultName){
        $versions = $versions | Where-Object { $vaultName -in $_.replicaInfo.replicaVec.target.archivalTarget.name }
    }

    if($versions){
        if($backupDate -match ':' -or $showVersions){
            $groups = $versions | Group-Object -Property {(usecsToDate $_.snapshotTimestampUsecs).ToString('yyyy/MM/dd HH:mm')}
        }else{
            $groups = $versions | Group-Object -Property {(usecsToDate $_.snapshotTimestampUsecs).ToString('yyyy/MM/dd')}
        }
        if($showVersions -or $showDates){
            $groups | Format-Table -Property @{l='Available Dates';e={$_.Name}}
            exit 0
        }
        if($backupDate){
            $group = $groups | Where-Object { $_.Name -eq $backupDate }
            if(! $group){
                write-host "No backups from that date!" -ForegroundColor Yellow
                exit 1
            }
            $version = $group.Group[0]
        }else{
            $version = $versions[0]
        }
    }else{
        write-host "No backups available!" -ForegroundColor Yellow
        exit 1
    }

    $replicas = $version.replicaInfo.replicaVec

    $view = api get views/$($doc.objectName)?includeInactive=True

    $cloneTask = @{
        "name"       = "Clone-View_" + $((get-date).ToString().Replace('/', '_').Replace(':', '_').Replace(' ', '_'));
        "objects"    = @(
            @{
                "jobUid"         = $doc.objectId.jobUid;
                "jobId"          = $doc.objectId.jobId;
                "jobInstanceId"  = $version.instanceId.jobInstanceId;
                "startTimeUsecs" = $version.instanceId.jobStartTimeUsecs;
                "entity"         = $doc.objectId.entity; 
            }
        )
        "viewName"   = $newName;
        "action"     = 5;
        "viewParams" = @{
            "sourceViewName"        = $view.name;
            "cloneViewName"         = $newName;
            "viewBoxId"             = $view.viewBoxId;
            "viewId"                = $doc.objectId.entity.id;
            "qos"                   = $view.qos;
            "description"           = $view.description;
            "allowMountOnWindows"   = $view.allowMountOnWindows;
            "storagePolicyOverride" = $view.storagePolicyOverride;
        }
    }

    if($vaultName -or $replicas[0].target.type -ne 1){
        $archivalTarget = ($replicas | Where-Object {$_.target.archivalTarget.name -eq 'S3'})[0].target.ArchivalTarget
        $cloneTask.objects[0]['archivalTarget'] = $archivalTarget
    }

    $cloneOp = api post /clone $cloneTask
    if ($cloneOp) {
        $source = ''
        if($vaultName){ $source = "from external target: $vaultName"}
        "Cloning {0} from {1} ({2}) {3}" -f $newName, $viewName, $group.Name, $source
    }
}else{
    write-host "View $viewName Not Found" -ForegroundColor Yellow
}
