# usage: ./cloneSQLbackup.ps1 -vip mycluster `
#                                -username myuser `
#                                -domain mydomain.net
#                                -jobName 'My SQL VDI Job' `
#                                -object myobject.mydomain.net `
#                                -viewName cloned

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][array]$access,
    [Parameter()][string]$objectName,
    [Parameter()][string]$jobName,
    [Parameter()][string]$viewName,
    [Parameter()][switch]$listRuns,
    [Parameter()][switch]$deleteView,
    [Parameter()][Int64]$firstRunId,
    [Parameter()][Int64]$lastRunId,
    [Parameter()][switch]$refreshView,
    [Parameter()][switch]$force,
    [Parameter()][switch]$consolidate,
    [Parameter()][string]$targetPath = $null,
    [Parameter()][switch]$dbFolders,
    [Parameter()][switch]$logsOnly,
    [Parameter()][switch]$lastRunOnly
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey
}else{
    apiauth -vip $vip -username $username -domain $domain
}

if(!$deleteView){
    if(!$jobName){
        Write-Host "JobName parameter required" -ForegroundColor Yellow
        exit 1
    }
}
if(!$viewName){
    $viewName = "$jobName".Replace(' ','-')
}


$view = (api get views).views | Where-Object {$_.name -eq $viewName}

# delete view
if($deleteView){
    "Deleting old view..."
    if(!$force){
        write-host "*** Warning: you are about to delete view $viewName! ***" -ForegroundColor Red
        $confirm = Read-Host -Prompt "Are you sure? Yes(No)"
        if($confirm.ToLower() -eq 'yes' -or $confirm.ToLower() -eq 'y'){
            $null = api delete "views/$viewName"
        }
    }else{
        $null = api delete "views/$viewName"
    }
    exit 0
}

if($refreshView){
    if($view){
        if(!$force){
            write-host "*** Warning: you are about to delete files from view $viewName! ***" -ForegroundColor Red
            $confirm = Read-Host -Prompt "Are you sure? Yes(No)"
            if($confirm.ToLower() -eq 'yes' -or $confirm.ToLower() -eq 'y'){
                "Refreshing View..."
                Get-ChildItem -Path "\\$vip\$viewName" | ForEach-Object {Remove-Item -Recurse -Path $_.FullName}
            }else{
                exit 0
            }
        }else{
            "Refreshing View..."
            Get-ChildItem -Path "\\$vip\$viewName" | ForEach-Object {Remove-Item -Recurse -Path $_.FullName}
        }
    }
}

# find job
$job = api get protectionJobs | Where-Object name -eq $jobName
if(!$job){
    Write-Host "Job $jobName not found" -ForegroundColor Yellow
    exit 1
}
$job = ($job | Sort-Object id)[-1]

$storageDomainId = $job.viewBoxId

# get runs
$runs = (api get "protectionRuns?jobId=$($job.id)")  | Where-Object{ $_.backupRun.snapshotsDeleted -eq $false }

if($lastRunOnly -and $runs.Count -gt 0){
    $runs = $runs[0]
}

if($firstRunId){
    $runs = $runs | Where-Object {$_.backupRun.jobRunId -ge $firstRunId}
}

if($lastRunId){
    $runs = $runs | Where-Object {$_.backupRun.jobRunId -le $lastRunId}
}

if($listRuns){
    $runs | Select-Object -Property @{label='runId'; expression={$_.backupRun.jobRunId}}, 
                                    @{label='runDate'; expression={usecsToDate $_.backupRun.stats.startTimeUsecs}},
                                    @{label='runType'; expression={$_.backupRun.runType.substring(1)}}
                                    
    exit 0
}

if($view -and !($deleteView -or $refreshView)){
    Write-Host "View $viewName already exists" -ForegroundColor Yellow
    exit 1
}

if(!$view){

    $newView = @{
        "enableSmbAccessBasedEnumeration" = $false;
        "enableSmbViewDiscovery" = $true;
        "fileDataLock" = @{
          "lockingProtocol" = "kSetReadOnly"
        };
        "fileExtensionFilter" = @{
          "isEnabled" = $false;
          "mode" = "kBlacklist";
          "fileExtensionsList" = @()
        };
        "securityMode" = "kNativeMode";
        "sharePermissions" = @();
        "smbPermissionsInfo" = @{
          "ownerSid" = "S-1-5-32-544";
          "permissions" = @()
        };
        "protocolAccess" = "kSMBOnly";
        "subnetWhitelist" = @();
        "caseInsensitiveNamesEnabled" = $true;
        "storagePolicyOverride" = @{
          "disableInlineDedupAndCompression" = $false
        };
        "qos"                             = @{
            "principalName" = "TestAndDev High"
        };
        "viewBoxId"                       = $storageDomainId;
        "name"                            = $viewName
    }
 
    function addPermission($user, $perms){
        $domain, $domainuser = $user.split('\')
        $principal = api get "activeDirectory/principals?domain=$domain&includeComputers=true&search=$domainuser" | Where-Object fullName -eq $domainuser
        if($principal){
            $permission = @{
                "sid" = $principal.sid;
                "type" = "kAllow";
                "mode" = "kFolderSubFoldersAndFiles";
                "access" = $perms
            }
            $newView.sharePermissions += $permission
            $newView.smbPermissionsInfo.permissions += $permission
        }else{
            Write-Warning "User $user not found"
            exit 1
        }
    }

    if($access){
        foreach($user in $access){
            addPermission $user 'kFullControl'
        }
    }else{
        $permission += @{
            "sid" = "S-1-1-0";
            "access" = "kFullControl";
            "mode" = "kFolderSubFoldersAndFiles";
            "type" = "kAllow"
        }
        $newView.sharePermissions += $permission
        $newView.smbPermissionsInfo.permissions += $permission
    }

    Write-Host "Creating new view $viewName"
    $view = api post views $newView
}

Write-Host "Cloning backup files..."
Start-Sleep 3
$view = (api get views).views | Where-Object {$_.name -eq $viewName}

$paths = @()
foreach($run in $runs){
    if($objectName){
        $sourceInfo = $run.backupRun.sourceBackupStatus | Where-Object {$_.source.name -eq $objectName}
        if(!$sourceInfo){ 
            write-host "$objectName not found in job run" -ForegroundColor Yellow
        }
    }

    foreach($sourceInfo in $run.backupRun.sourceBackupStatus){
        if(!$objectName -or $sourceInfo.source.name -eq $objectName){
            $thisObjectName = $sourceInfo.source.name
            if($sourceInfo.status -in @('kSuccess', 'kWarning')){
                $sourceView = $sourceInfo.currentSnapshotInfo.viewName
                $x = $attemptNum = 1
                if($sourceInfo.currentSnapshotInfo.PSObject.Properties['relativeSnapshotDirectory']){
                    $sourcePath = $sourceInfo.currentSnapshotInfo.relativeSnapshotDirectory
                    $sourcePathPrefix = $sourcePath.Substring(0,$sourcePath.length - $sourcePath.split('-')[-1].length)
                    $attemptnum = $sourcePath.split('-')[-1]
                }else{
                    $sourcePath = '/'
                }
                while($x -le $attemptnum){
                    if($sourceInfo.currentSnapshotInfo.PSObject.Properties['relativeSnapshotDirectory']){
                        $sourcePath = "$sourcePathPrefix$($x)"
                    }
                    # $sourcePath
                    $destinationPath = "$thisObjectName-$((usecsToDate $run.backupRun.stats.startTimeUsecs).ToString("yyyy-MM-dd_HH-mm-ss"))-$($run.backupRun.runType.substring(1))-$x"
                    $runDate = (usecsToDate $run.backupRun.stats.startTimeUsecs).ToString("yyyy-MM-dd_HH-mm-ss")
                
                    # clone snapshot directory
                    $CloneDirectoryParams = @{
                        'destinationDirectoryName' = $destinationPath;
                        'destinationParentDirectoryPath' = "/$viewName";
                        'sourceDirectoryPath' = "/$sourceView/$SourcePath"
                    }
                
                    $folderPath = "\\$vip\$viewName\$destinationPath"
                    Write-Host "Cloning $thisObjectName backup files to $folderPath"
                    $null = api post views/cloneDirectory $CloneDirectoryParams
                    $paths += @{'path' = $folderPath; 'runDate' = $runDate; 'runType' = $run.backupRun.runType}
                    $x = $x + 1
                }
            }
        }
    }
}

$backupFolderPath = "\\$vip\$viewName"

if($consolidate -or $targetPath){
    Write-Host "Consolidating files..."
    if($targetPath){
        $backupFolderPath = "{0}{1}" -f $backupFolderPath, $targetPath
        $null = New-Item -Path $backupFolderPath -ItemType Directory -Force
    }
    foreach($item in $paths){
        $itemPath = $item.path
        $runDate = $item.runDate
        $runType = $item.runType
        $folders = $null
        while($True){
            $folders = Get-ChildItem -Path $itemPath -ErrorAction SilentlyContinue
            if($folders){
                break
            }
            Start-Sleep 1
        }
        
        foreach($folder in $folders){
            $files = $null
            while($True){
                $files = Get-ChildItem -Path $folder.fullName -ErrorAction SilentlyContinue
                if($files){
                    break
                }
                Start-Sleep 1
            }
            
            $instance, $dbid, $createmsecs, $dbname = $folder.Name.split('_',4)
    
            foreach($file in $files){
                if($file.Name -ne 'common'){
                    if($runType -eq 'kLog'){
                        $newName = "$($runDate)_$($dbname).trn"
                    }else{
                        $newName = "$($runDate)_$($dbname)_$($file.Name)"
                    }
                    if($runType -eq 'kLog' -or !$logsOnly){
                        # $newName
                        $fileDestination = "$backupFolderPath\$newName"
                        if($dbFolders){
                            $null = New-Item -Path "$backupFolderPath\$dbName" -ItemType Directory -Force
                            $fileDestination = "$backupFolderPath\$dbName\$newName"
                        }
                        while($True){
                            if(Move-Item -Path $file.FullName -Destination $fileDestination -PassThru){
                                break
                            }
                            Start-Sleep 1
                        }
                    }
                }
            }
        }
        $null = Remove-Item -Path $itemPath -Recurse -ErrorAction SilentlyContinue
    }
}

write-host "`nFiles cloned to $backupFolderPath`n" 
