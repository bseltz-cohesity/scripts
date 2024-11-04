# usage: ./cloneBackupToView.ps1 -vip mycluster `
#                                -username myuser `
#                                -domain mydomain.net
#                                -jobName 'My SQL VDI Job' `
#                                -object myobject.mydomain.net `
#                                -viewName cloned

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][array]$access,
    [Parameter()][string]$objectName,
    [Parameter()][string]$jobName,
    [Parameter()][string]$dirPath = '/',
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
    [Parameter()][switch]$objectView,
    [Parameter()][switch]$logsOnly,
    [Parameter()][switch]$lastRunOnly,
    [Parameter()][Int64]$daysToKeep = 0,
    [Parameter()][switch]$waitForRun, 
    [Parameter()][Int64]$numRuns = 100,
    [Parameter()][array]$ips,                         # optional cidrs to add (comma separated)
    [Parameter()][string]$ipList = '',                # optional textfile of cidrs to add
    [Parameter()][switch]$rootSquash,                 # whether whitelist entries should use root squash
    [Parameter()][switch]$allSquash,                  # whether whitelist entries should use all squash
    [Parameter()][switch]$readOnly                    # grant only read access
)

if($objectView){
    if(!$objectName){
        Write-Host "-objectName is required when using -objectView" -ForegroundColor Yellow
        exit
    }
    $viewName = $objectName.split('.')[0]
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================


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

function netbitsToDDN($netBits){
    $maskBits = '1' * $netBits + '0' * (32 - $netBits)
    $octet1 = [convert]::ToInt32($maskBits.Substring(0,8),2)
    $octet2 = [convert]::ToInt32($maskBits.Substring(8,8),2)
    $octet3 = [convert]::ToInt32($maskBits.Substring(16,8),2)
    $octet4 = [convert]::ToInt32($maskBits.Substring(24,8),2)
    return "$octet1.$octet2.$octet3.$octet4"
}

function newWhiteListEntry($cidr, $perm){
    $ip, $netbits = $cidr -split '/'
    if(! $netbits){
        $netbits = '32'
    }
    $maskDDN = netbitsToDDN $netbits
    $whitelistEntry = @{
        "nfsAccess" = $perm;
        "smbAccess" = $perm;
        "s3Access" = $perm;
        "ip"            = $ip;
        "netmaskIp4"    = $maskDDN
    }
    if($allSquash){
        $whitelistEntry['nfsAllSquash'] = $True
    }
    if($rootSquash){
        $whitelistEntry['nfsRootSquash'] = $True
    }
    return $whitelistEntry
}

$ipaddrs = @(gatherList -Param $ips -FilePath $ipList -Name 'whitelist ips' -Required $false)

$perm = 'kReadWrite'
if($readOnly){
    $perm = 'kReadOnly'
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
                Get-ChildItem -Path "\\$vip\$viewName" | ForEach-Object {
                    Remove-Item -Recurse -Path $_.FullName
                }
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
If($daysToKeep -gt 0){
    $daysToKeepUsecs = timeAgo $daysToKeep days
    $runTail = "numRuns=$numRuns&startTimeUsecs=$daysToKeepUsecs"
}else{
    $runTail = "numRuns=$numRuns"
}

$finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning', '3', '4', '5', '6')
if($waitForRun){
    "Waiting for Run Completion"
    while($True){
        $runs = (api get "protectionRuns?jobId=$($job.id)&$runTail")  | Where-Object{ $_.backupRun.snapshotsDeleted -eq $false}
        if($runs -and $runs.Count -gt 0){
            if($runs[0].backupRun.status -in $finishedStates){
                break
            }
        }
        Start-Sleep 15
    }
}else{
    $runs = (api get "protectionRuns?jobId=$($job.id)&$runTail")  | Where-Object{ $_.backupRun.snapshotsDeleted -eq $false }
}

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

if(!$view){
    $newView = @{
        "enableSmbAccessBasedEnumeration" = $false;
        "enableSmbViewDiscovery"          = $true;
        "fileDataLock"                    = @{
            "lockingProtocol" = "kSetReadOnly"
        };
        "fileExtensionFilter"             = @{
            "isEnabled"          = $false;
            "mode"               = "kBlacklist";
            "fileExtensionsList" = @()
        };
        "securityMode"                    = "kNativeMode";
        "sharePermissions"                = @();
        "smbPermissionsInfo"              = @{
            "ownerSid"    = "S-1-5-32-544";
            "permissions" = @()
        };
        "protocolAccess"                  = "kSMBOnly";
        "subnetWhitelist"                 = @();
        "caseInsensitiveNamesEnabled"     = $true;
        "storagePolicyOverride"           = @{
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

# add whitelist entries
if($ipaddrs.Count -gt 0){
    if(! $view.PSObject.Properties['subnetWhitelist']){
        setApiProperty -object $view -name 'subnetWhitelist' -value @()
    }
    
    foreach($cidr in $ipaddrs){
        $ip, $netbits = $cidr -split '/'
        $view.subnetWhitelist = @($view.subnetWhiteList | Where-Object ip -ne $ip)
        $view.subnetWhitelist = @($view.subnetWhiteList +(newWhiteListEntry $cidr $perm))
    }
    $null = api put views $view
}

$paths = @()
foreach($run in $runs){
    if($objectName){
        $sourceInfo = $run.backupRun.sourceBackupStatus | Where-Object {$_.source.name -eq $objectName}
        if(!$sourceInfo){ 
            write-host "$objectName not found in job run" -ForegroundColor Yellow
        }
    }

    foreach($sourceInfo in $run.backupRun.sourceBackupStatus){
        if($job.environment -ne 'kSQL' -or $sourceInfo.PSObject.Properties['appsBackupStatus']){
            if(!$objectName -or $sourceInfo.source.name -eq $objectName){
                $thisObjectName = $sourceInfo.source.name
                if($sourceInfo.status -in @('kSuccess', 'kWarning', '4', '6')){
                    if($sourceInfo.currentSnapshotInfo.PSObject.Properties['viewName']){
                        $sourceView = $sourceInfo.currentSnapshotInfo.viewName
                    }elseif($sourceInfo.currentSnapshotInfo.PSObject.Properties['rootPath']){
                        $sourceView = $sourceInfo.currentSnapshotInfo.rootPath.split('/')[2]
                    }else{
                        $thisRun = api get "/backupjobruns?exactMatchStartTimeUsecs=$($run.backupRun.stats.startTimeUsecs)&id=$($run.jobId)"
                        if($thisRun.backupJobRuns.protectionRuns[0].backupRun.latestFinishedTasks[0].PSObject.Properties['viewName']){
                            $sourceView = $thisRun.backupJobRuns.protectionRuns[0].backupRun.latestFinishedTasks[0].viewName
                        }elseif($thisRun.backupJobRuns.protectionRuns[0].backupRun.latestFinishedTasks[0].currentSnapshotInfo.PSObject.Properties['viewName']){
                            $sourceView = $thisRun.backupJobRuns.protectionRuns[0].backupRun.latestFinishedTasks[0].currentSnapshotInfo.viewName
                        }else{
                            Write-Host "no view path found for $($job.environment) protection run" -ForegroundColor Yellow
                            continue
                        }                        
                    }
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
                        $destinationPath = "$((usecsToDate $run.backupRun.stats.startTimeUsecs).ToString("yyyy-MM-dd_HH-mm-ss"))---$thisObjectName---$($run.backupRun.runType.substring(1))-$x"
                        $runDate = (usecsToDate $run.backupRun.stats.startTimeUsecs).ToString("yyyy-MM-dd_HH-mm-ss")
                    
                        # clone snapshot directory
                        $CloneDirectoryParams = @{
                            'destinationDirectoryName' = $destinationPath;
                            'destinationParentDirectoryPath' = "/$viewName";
                            'sourceDirectoryPath' = "/$sourceView/$SourcePath"
                        }
                        if($dirPath -ne '/'){
                            $CloneDirectoryParams['sourceDirectoryPath'] = "{0}{1}" -f $CloneDirectoryParams['sourceDirectoryPath'], $dirPath
                        }
                        $folderPath = "\\$vip\$viewName\$destinationPath"
                        
                            Write-Host "Cloning $thisObjectName backup files to $folderPath"
                            $null = api post views/cloneDirectory $CloneDirectoryParams  # -quiet
                        
                        # Write-Host "Cloning $thisObjectName backup files to $folderPath"
                        # $null = api post views/cloneDirectory $CloneDirectoryParams  # -quiet
                        if($cohesity_api.last_api_error -match 'kPermissionDenied'){
                            Write-Host "`nAccess Denied. Cluster config must be modified. Add:`n`n    bridge_enable_secure_view_access: false`n" -ForegroundColor Yellow
                            exit
                        }
                        $paths += @{'path' = $folderPath; 'runDate' = $runDate; 'runType' = $run.backupRun.runType; 'sourceName' = $sourceInfo.source.name}
                        $x = $x + 1
                    }
                }
            }
        }
    }
}

$backupFolderPath = "\\$vip\$viewName"

if($consolidate -or $dbFolders -or $objectView){
    Write-Host "Consolidating files..."
    if($targetPath){
        $backupFolderPath = "{0}{1}" -f $backupFolderPath, $targetPath
        $null = New-Item -Path $backupFolderPath -ItemType Directory -Force
    }
    foreach($item in $paths){
        $itemPath = $item.path
        write-host "$itemPath"
        $runDate = $item.runDate
        $runType = $item.runType
        $sourceName = $item.sourceName
        $folders = $null
        $i = 0
        while($i -lt 60){
            $i += 1
            $folders = Get-ChildItem -Path "$itemPath" -ErrorAction SilentlyContinue
            if($folders){
                break
            }
            Start-Sleep 2
        }
        foreach($folder in $folders){
            $files = $null
            while($True){
                $files = Get-ChildItem -Path $folder.fullName -ErrorAction SilentlyContinue
                if($files){
                    break
                }
                Start-Sleep 2
            }
            
            $instance, $dbid, $createmsecs, $dbname = $folder.Name.split('_',4)
    
            foreach($file in $files){
                if(! $dbname){
                    $dbname = $file.Directory.Name.split('---')[0]
                }
                if($file.Name -ne 'common'){
                    if($objectView){
                        if($runType -eq 'kLog' -or !$logsOnly){
                            if(!(Test-Path -Path "$backupFolderPath\$dbName\$runDate--$($runType.substring(1))")){
                                $null = New-Item -Path "$backupFolderPath\$dbName\$runDate--$($runType.substring(1))" -ItemType Directory -Force
                            }
                            $fileDestination = "$backupFolderPath\$dbName\$runDate--$($runType.substring(1))\"
                            while($True){
                               
                                if(Test-Path -Path "$($fileDestination)$($file.Name)"){
                                    # Write-Host "    Already Exists $($fileDestination)$($file.Name)"
                                    break
                                }
                                if(Move-Item -Path $file.FullName -Destination $fileDestination -PassThru -Force){
                                    break
                                }
                                Start-Sleep 1
                            }
                        }
                    }else{
                        if($runType -eq 'kLog'){
                            $newName = "$($runDate)---$sourceName---$($dbname).trn"
                        }else{
                            $newName = "$($runDate)---$sourceName---$($dbname)---$($file.Name)"
                        }
                        if($runType -eq 'kLog' -or !$logsOnly){
                            $fileDestination = "$backupFolderPath\$newName"
                            if($dbFolders){
                                if(!(Test-Path -Path "$backupFolderPath\$sourceName---$dbName")){
                                    $null = New-Item -Path "$backupFolderPath\$sourceName---$dbName" -ItemType Directory -Force
                                }
                                $fileDestination = "$backupFolderPath\$sourceName---$dbName\$newName"
                            }
                            while($True){
                                if(Test-Path -Path "$($fileDestination)$($file.Name)"){
                                    # Write-Host "    Already Exists $($fileDestination)$($file.Name)"
                                    break
                                }
                                if(Move-Item -Path $file.FullName -Destination $fileDestination -PassThru -Force){
                                    break
                                }
                                Start-Sleep 1
                                write-host "sleeping"
                            }
                        }
                    }
                }
            }
        }
        $null = Remove-Item -Path $itemPath -Recurse -ErrorAction SilentlyContinue
    }
}

$today = Get-Date
if($daysToKeep -gt 0){
    $fileset = Get-ChildItem -Path $backupFolderPath -Recurse
    foreach($file in $fileset){
        $fdate = (($file.Name -split '---')[0] -split '_')[0] -as [DateTime]
        if($fdate){
            if($fdate.AddDays($daysToKeep + 1) -lt $today){
                $null = Remove-Item -Path $file.FullName -Recurse -ErrorAction SilentlyContinue
            }
        }
    }
}

write-host "`nFiles cloned to $backupFolderPath`n" 
