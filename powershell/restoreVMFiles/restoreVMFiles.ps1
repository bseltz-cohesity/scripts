# 2023-01-26
# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',   # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',           # username (local or AD)
    [Parameter()][string]$domain = 'local',              # local or AD domain
    [Parameter()][switch]$useApiKey,                     # use API key for authentication
    [Parameter()][string]$password,                      # optional password
    [Parameter()][switch]$noPrompt,                      # do not prompt for password
    [Parameter()][string]$tenant,                        # org to impersonate
    [Parameter()][switch]$mcm,                           # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,               # MFA code
    [Parameter()][switch]$emailMfaCode,                  # email MFA code
    [Parameter()][string]$clusterName = $null,           # helios cluster to access
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
    [Parameter()][switch]$noIndex, # deprecated
    [Parameter()][switch]$localOnly,
    [Parameter()][switch]$overwrite,
    [Parameter()][string]$taskString = '',
    [Parameter()][int]$vlan = 0
)

if($overWrite){
    $override = $True
}else{
    $override = $False
}

if($taskString -eq ''){
    $taskString = $sourceVM
}

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
$object = ($object | Sort-Object -Property @{Expression={$_.latestSnapshotsInfo[0].protectionRunStartTimeUsecs}; Ascending = $False})[0]

# get snapshots
$objectId = $object.id
$groupId = $object.latestSnapshotsInfo[0].protectionGroupId
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
    # $snapshotId = $snapshot.id
}elseif($olderThan){
    # select lastest run before olderThan date
    $olderThanUsecs = dateToUsecs $olderThan
    $olderSnapshots = $snapshots.snapshots | Where-Object {$olderThanUsecs -gt $_.runStartTimeUsecs}
    if($olderSnapshots){
        $snapshot = $olderSnapshots[-1]
    }else{
        Write-Host "Oldest snapshot is $(usecsToDate $snapshots.snapshots[0].runStartTimeUsecs)"
        exit 1
    }
}else{
    # use latest run
    $snapshot = $snapshots.snapshots[-1]
}
$snapshotId = $snapshot.id
# if($snapshot.PSObject.Properties['indexingStatus'] -and $snapshot.indexingStatus -eq 'Done'){
#     $noIndex = $False
# }else{
#     $noIndex = $True
# }

$dateString = get-date -UFormat '%Y-%m-%d_%H-%M-%S'

$restoreParams = @{
    "snapshotEnvironment" = "kVMware";
    "name"                = "RestoreFiles_$($taskString)_$($dateString)";
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
                "overwriteExisting"       = $override;
                "preserveAttributes"      = $true;
                "continueOnError"         = $true;
                "encryptionEnabled"       = $false
            }
        }
    }
}

# select cluster interface
if($vlan -gt 0){
    $vlanObj = api get vlans | Where-Object id -eq $vlan
    if($vlanObj){
        $restoreParams.vmwareParams.recoverFileAndFolderParams.vmwareTargetParams['vlanConfig'] = @{
            "id" = $vlanObj.id;
            "interfaceName" = $vlanObj.ifaceGroupName.split('.')[0]
        }
    }else{
        Write-Host "vlan $vlan not found" -ForegroundColor Yellow
        exit
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
    if($noIndex -eq $True){
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