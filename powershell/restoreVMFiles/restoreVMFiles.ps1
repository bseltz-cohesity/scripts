# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, # Cohesity username
    [Parameter()][string]$domain = 'local', # Cohesity user domain name
    [Parameter()][switch]$useApiKey, # use API key for authentication
    [Parameter()][string]$password = $null,
    [Parameter(Mandatory = $True)][string]$sourceVM, # name of source VM
    [Parameter()][string]$targetVM, # name of target VM
    [Parameter()][array]$fileNames, # one or more file paths
    [Parameter()][string]$fileList, # text file of file paths
    [Parameter()][string]$vmUser, # user name for vmtools 
    [Parameter()][string]$vmPwd, # password for vm tools
    [Parameter()][string]$restorePath, # alternate path to restore files
    [Parameter()][ValidateSet('ExistingAgent','AutoDeploy','VMTools')][string]$restoreMethod = 'AutoDeploy',
    [Parameter()][switch]$wait, # wait for completion and report status
    [Parameter()][switch]$showVersions, # show available run dates
    [Parameter()][string]$runId, # restore from specified run ID
    [Parameter()][string]$olderThan, # restore from latest backup before date
    [Parameter()][int]$daysAgo, # restore from backup X days ago
    [Parameter()][switch]$noIndex,
    [Parameter()][switch]$localOnly
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

$restoreMethods = @{
    'ExistingAgent' = 'UseExistingAgent';
    'AutoDeploy' = 'AutoDeploy';
    'VMTools' = 'UseHypervisorApis'
}

# gather file names
$files = @()
if($fileList -and (Test-Path $fileList -PathType Leaf)){
    $files += Get-Content $fileList | Where-Object {$_ -ne ''}
}elseif($fileList){
    Write-Warning "File $fileList not found!"
    exit 1
}
if($fileNames){
    $files += $fileNames
}
if($files.Length -eq 0){
    Write-Host "No files selected for restore"
    exit 1
}

# convert to unix style file paths
$files = [string[]]$files | ForEach-Object {("/" + $_.Replace('\','/').replace(':','')).Replace('//','/')}

# find source object
$objects = api get "data-protect/search/protected-objects?snapshotActions=RecoverFiles&searchString=$sourceVM&environments=kVMware" -v2
$object = $objects.objects | Where-Object name -eq $sourceVM
if(!$object){
    Write-Host "VM $sourceVM not found" -ForegroundColor Yellow
    exit 1
}

# get snapshots
$objectId = $object[0].id
$groupId = $object[0].latestSnapshotsInfo[0].protectionGroupId
$snapshots = api get "data-protect/objects/$objectId/snapshots?protectionGroupIds=$groupId" -v2
if($localOnly){
    $snapshots.snapshots = $snapshots.snapshots | Where-Object {$_.snapshotTargetType -eq 'Local'}
}

# list versions
if($showVersions){
    $snapshots.snapshots | Select-Object -Property @{label='runId'; expression={$_.runInstanceId}}, @{label='runDate'; expression={usecsToDate $_.runStartTimeUsecs}}
    exit 0
}

# version selection
if($daysAgo -gt 0){
    # set olderThan to X days ago
    $thisMorning = Get-Date -Hour 0 -Minute 00 -Second 00
    $olderThan = $thisMorning.AddDays(-($daysAgo - 1))
}
if($runId){
    # select specific run ID
    $snapshot = $snapshots.snapshots | Where-Object runInstanceId -eq $runId
    if(! $snapshot){
        Write-Host "runId $runId not found" -ForegroundColor Yellow
        exit 1
    }
    $snapshotId = $snapshot.id
}elseif($olderThan){
    # select lastest run before olderThan date
    $olderThanUsecs = dateToUsecs $olderThan
    $olderSnapshots = $snapshots.snapshots | Where-Object {$olderThanUsecs -gt $_.runStartTimeUsecs}
    if($olderSnapshots){
        $snapshotId = $olderSnapshots[-1].id
    }else{
        Write-Host "Oldest snapshot is $(usecsToDate $snapshots.snapshots[0].runStartTimeUsecs)"
        exit 1
    }
}else{
    # use latest run
    $snapshotId = $snapshots.snapshots[-1].id
}

$dateString = get-date -UFormat '%Y-%m-%d_%H-%M-%S'

$restoreParams = @{
    "snapshotEnvironment" = "kVMware";
    "name"                = "Recover_$dateString";
    "vmwareParams"        = @{
        "objects"                    = @(
            @{
                "snapshotId" = $snapshotId
            }
        );
        "recoveryAction"             = "RecoverFiles";
        "recoverFileAndFolderParams" = @{
            "filesAndFolders"    = @();
            "targetEnvironment"  = "kVMware";
            "vmwareTargetParams" = @{
                "recoverToOriginalTarget" = $true;
                "overwriteExisting"       = $true;
                "preserveAttributes"      = $true;
                "continueOnError"         = $true;
                "encryptionEnabled"       = $false
            }
        }
    }
}

# set VM credentials
if($restoreMethod -ne 'ExistingAgent'){
    if(!$vmUser){
        Write-Host "VM credentials required for 'AutoDeploy' and 'VMTools' restore methods" -ForegroundColor Yellow
        exit 1
    }
    if(!$vmPwd){
        $secureString = Read-Host -Prompt "Enter password for VM user ($vmUser)" -AsSecureString
        $vmPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
    }
    $vmCredentials = @{
        "username" = $vmUser;
        "password" = $vmPwd
    }
}

# find target object
if($targetVM){
    if(!$restorePath){
        Write-Host "restorePath required when restoring to alternate target VM" -ForegroundColor Yellow
        exit 1
    }
    $vms = api get protectionSources/virtualMachines
    $targetObject = $vms | where-object name -eq $targetVM
    if(!$targetObject){
        Write-Host "VM $targetVM not found" -ForegroundColor Yellow
        exit 1
    }
    $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams.recoverToOriginalTarget = $false
    $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams['newTargetConfig']= @{
        "targetVm" = @{
          "id" = $targetObject[0].id
        };
        "recoverMethod" = $restoreMethods[$restoreMethod];
        "absolutePath" = $restorePath;
    }
    if($restoreMethod -ne 'ExistingAgent'){
        $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams.newTargetConfig["targetVmCredentials"] = $vmCredentials
    }
}else{
    # original target config
    $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams["originalTargetConfig"] = @{
        "recoverMethod"         = $restoreMethods[$restoreMethod];
    }
    if($restorePath){
        $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams.originalTargetConfig.recoverToOriginalPath = $false
        $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams.originalTargetConfig["alternatePath"] = $restorePath
    }else{
        $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams.originalTargetConfig["recoverToOriginalPath"] = $true
    }
    if($restoreMethod -ne 'ExistingAgent'){
        $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams.originalTargetConfig["targetVmCredentials"] = $vmCredentials
    }
}

# find files for restore
foreach($file in $files){
    if($noIndex){
        if($file[-1] -eq '/'){
            $isDirectory = $True
        }else{
            $isDirectory = $false
        }
        $restoreParams.vmwareParams.recoverFileAndFolderParams.filesAndFolders += @{
            "absolutePath" = $file;
            "isDirectory" = $isDirectory
        }
    }else{
        $searchParams = @{
            "fileParams" = @{
                "searchString"       = $file;
                "sourceEnvironments" = @(
                    "kVMware"
                );
                "objectIds"          = @(
                    $objectId
                )
            };
            "objectType" = "Files"
        }
        $search = api post -v2 "data-protect/search/indexed-objects" $searchParams
        $thisFile = $search.files | Where-Object {("{0}/{1}" -f $_.path, $_.name) -eq $file -or ("{0}/{1}/" -f $_.path, $_.name) -eq $file}
        if(!$thisFile){
            Write-Host "file $file not found" -ForegroundColor Yellow
        }else{
            if($file[-1] -eq '/'){
                $isDirectory = $True
                $absolutePath = "{0}/{1}/" -f $thisFile[0].path, $thisFile[0].name
            }else{
                $isDirectory = $false
                $absolutePath = "{0}/{1}" -f $thisFile[0].path, $thisFile[0].name
            }
            $restoreParams.vmwareParams.recoverFileAndFolderParams.filesAndFolders += @{
                "absolutePath" = $absolutePath;
                "isDirectory" = $isDirectory
            }
        }
    }
}

# perform restore
if($restoreParams.vmwareParams.recoverFileAndFolderParams.filesAndFolders.Count -gt 0){
    $restoreTask = api post 'data-protect/recoveries' $restoreParams -v2
    $restoreTaskId = $restoreTask.id
    Write-Host "Restoring Files..."
    if($wait){
        while($restoreTask.status -eq "Running"){
            Start-Sleep 5
            $restoreTask = api get -v2 "data-protect/recoveries/$($restoreTaskId)?includeTenants=true"
        }
        if($restoreTask.status -eq 'Succeeded'){
            Write-Host "Restore $($restoreTask.status)"
        }else{
            Write-Host "Restore $($restoreTask.status): $($restoreTask.messages -join ', ')" -ForegroundColor Yellow
        }
    }
}else{
    Write-Host "No files found for restore" -ForegroundColor Yellow
}
