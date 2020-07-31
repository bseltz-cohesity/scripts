# usage: ./cloneSQLVDIbackup.ps1 -vip mycluster `
#                                -username myuser `
#                                -domain mydomain.net
#                                -jobName 'My SQL VDI Job' `
#                                -sqlServer mysqlserver.mydomain.net `
#                                -viewName cloned

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$viewName,
    [Parameter()][string]$storageDomain = 'DefaultStorageDomain',
    [Parameter()][string]$sqlServer,
    [Parameter()][string]$jobName,
    [Parameter()][switch]$listRuns,
    [Parameter()][switch]$deleteView,
    [Parameter()][Int64]$runId
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# delete view
if($deleteView){
    if(!$viewName){
        Write-Host "-viewName parameter required" -ForegroundColor Yellow
        exit 1
    }
    write-host "*** Warning: you are about to delete view $viewName! ***" -ForegroundColor Red
    $confirm = Read-Host -Prompt "Are you sure? Yes(No)"
    if($confirm.ToLower() -eq 'yes'){
        $null = api delete views/$viewName
    }
    exit 0
}else{
    if(!$jobName){
        Write-Host "-jobName parameter required" -ForegroundColor Yellow
        exit 1
    }
}

# find job
$job = api get protectionJobs | Where-Object name -eq $jobName
if(!$job){
    Write-Host "Job $jobName not found" -ForegroundColor Yellow
    exit 1
}

# get runs
$runs = (api get "protectionRuns?jobId=$($job.id)")  | Where-Object{ $_.backupRun.snapshotsDeleted -eq $false }
if($listRuns){
    $runs | Select-Object -Property @{label='runId'; expression={$_.backupRun.jobRunId}}, @{label='runDate'; expression={usecsToDate $_.backupRun.stats.startTimeUsecs}}
    exit 0
}

if($runId){
   $run = $runs | Where-Object {$_.backupRun.jobRunId -eq $runId}
   if(!$run){
       Write-Host "Job run $runId not found" -ForegroundColor Yellow
       exit 1
   }
}else{
    $run = $runs[0]
}

if(!$sqlServer){
    Write-Host "-sqlServer parameter required" -ForegroundColor Yellow
    exit 1
}

# get or create view
if(!$viewName){
    Write-Host "-viewName parameter required" -ForegroundColor Yellow
    exit 1
}
$REPORTAPIERRORS = $false
$view = api get "views/$viewName"
$REPORTAPIERRORS = $True
if(!$view){
    $sd = api get viewBoxes | Where-Object name -eq $storageDomain
    if(!$sd){
        Write-Host "Storage domain $storageDomain not found" -ForegroundColor Yellow
        exit 1
    }
    $newView = @{
        "caseInsensitiveNamesEnabled"     = $true;
        "enableAppAwareUptiering"         = $true;
        "enableFastDurableHandle"         = $false;
        "enableNfsViewDiscovery"          = $true;
        "enableSmbAccessBasedEnumeration" = $false;
        "enableSmbMultichannel"           = $true;
        "enableSmbOplock"                 = $true;
        "enableSmbViewDiscovery"          = $true;
        "fileExtensionFilter"             = @{
            "isEnabled"          = $false;
            "mode"               = "kBlacklist";
            "fileExtensionsList" = @()
        };
        "nfsRootPermissions"              = @{
            "gid"  = 0;
            "mode" = 493;
            "uid"  = 0
        };
        "overrideGlobalWhitelist"         = $true;
        "prefetchSequencedFilenames"      = $true;
        "protocolAccess"                  = "kAll";
        "securityMode"                    = "kNativeMode";
        "sharePermissions"                = @(
            @{
                "sid"    = "S-1-1-0";
                "access" = "kFullControl";
                "mode"   = "kFolderSubFoldersAndFiles";
                "type"   = "kAllow"
            }
        );
        "smbPermissionsInfo"              = @{
            "ownerSid"    = "S-1-5-32-544";
            "permissions" = @(
                @{
                    "sid"    = "S-1-1-0";
                    "access" = "kFullControl";
                    "mode"   = "kFolderSubFoldersAndFiles";
                    "type"   = "kAllow"
                }
            )
        };
        "subnetWhitelist"                 = @();
        "qos"                             = @{
            "principalName" = "TestAndDev High"
        };
        "viewBoxId"                       = $sd.id;
        "name"                            = $viewName
    }
    Write-Host "Creating new view $viewName"
    $view = api post views $newView
}

# get snapshot path
$sourceInfo = $run.backupRun.sourceBackupStatus | Where-Object {$_.source.name -eq $sqlServer}
if(!$sourceInfo){
    write-host "$sqlServer not found in job run" -ForegroundColor Yellow
    exit 1
}

$sourceView = $sourceInfo.currentSnapshotInfo.viewName
$sourcePath = $sourceInfo.currentSnapshotInfo.relativeSnapshotDirectory
$destinationPath = "$sqlServer-$((usecsToDate $run.backupRun.stats.startTimeUsecs).ToString("yyyy-MM-dd_HH-mm-ss"))"

# clone snapshot directory
$CloneDirectoryParams = @{
    'destinationDirectoryName' = $destinationPath;
    'destinationParentDirectoryPath' = "/$viewName";
    'sourceDirectoryPath' = "/$sourceView/$sourcePath"
}

Write-Host "Cloning $sqlServer backup files to $($view.smbMountPath)\$destinationPath"
$null = api post views/cloneDirectory $CloneDirectoryParams
