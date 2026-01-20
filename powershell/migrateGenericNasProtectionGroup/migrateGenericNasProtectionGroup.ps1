# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$sourceCluster,
    [Parameter(Mandatory = $True)][string]$sourceUser,
    [Parameter()][string]$sourceDomain = 'local',
    [Parameter()][string]$sourcePassword = $null,
    [Parameter(Mandatory = $True)][string]$targetCluster,
    [Parameter()][string]$targetUser = $sourceUser,
    [Parameter()][string]$targetDomain = $sourceDomain,
    [Parameter()][string]$targetPassword = $null,
    [Parameter()][string]$tenant,
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][string]$prefix = '',
    [Parameter()][string]$suffix = '',
    [Parameter()][string]$oldJobSuffix = $null,
    [Parameter()][string]$newJobName = $jobName,
    [Parameter()][string]$newPolicyName,
    [Parameter()][string]$newStorageDomainName,
    [Parameter()][switch]$pauseNewJob,
    [Parameter()][switch]$cleanupSourceObjects,
    [Parameter()][switch]$cleanupSourceObjectsAndExit,
    [Parameter()][switch]$deleteOldSnapshots,
    [Parameter()][switch]$deleteReplica,
    [Parameter()][switch]$renameOldJob,
    [Parameter()][switch]$targetNGCE,
    [Parameter()][string]$smbUsername,
    [Parameter()][string]$smbPassword
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

function waitForRefresh($mountPoint){
    $authStatus = ""
    while($authStatus -ne 'kFinished'){
        Start-Sleep 2
        $rootNode = (api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false&environments=kGenericNas").rootNodes | Where-Object {$_.rootNode.name -eq $mountPoint}
        $authStatus = $rootNode.registrationInfo.authenticationStatus
    }
    return $rootNode.rootNode.id
}

"`nConnecting to source cluster..."
apiauth -vip $sourceCluster -username $sourceUser -domain $sourceDomain -passwd $sourcePassword -tenant $tenant -quiet

if($prefix){
    $newJobName = "$prefix-$newJobName"
}

if($suffix){
    $newJobName = "$newJobName-$suffix"
}

$smbPasswords = @{}

$job = (api get -v2 'data-protect/protection-groups?environments=kGenericNas').protectionGroups | Where-Object name -eq $jobName

if($job){

    # gather old job info
    $oldPolicy = (api get -v2 data-protect/policies).policies | Where-Object id -eq $job.policyId
    $oldStorageDomain = $null
    if($job.storageDomainId -ne $null){
        $oldStorageDomain = api get viewBoxes | Where-Object id -eq $job.storageDomainId
    }
   

    # connect to target cluster for sanity check
    if(!$cleanupSourceObjectsAndExit){
        "Connecting to target cluster..."
        apiauth -vip $targetCluster -username $targetUser -domain $targetDomain -passwd $targetPassword -tenant $tenant -quiet

        # check for existing job
        $existingJob = (api get -v2 'data-protect/protection-groups').protectionGroups | Where-Object name -eq $newJobName
        if($existingJob){
            if($existingJob.isActive -eq $false -and $deleteReplica){
                "    Deleting existing replica job..."
                $null = api delete -v2 data-protect/protection-groups/$($existingJob.id)
            }else{
                Write-Host "job '$newJobName' already exists on target cluster" -ForegroundColor Yellow
                exit
            }
        }

        # check for target storage domain
        $newStorageDomain = $null
        if(!$targetNGCE){
            # check for target storage domain
            if($newStorageDomainName){
                $oldStorageDomain.name = $newStorageDomainName
            }
            
            $newStorageDomain = $null
            if($oldStorageDomain -ne $null){
                $newStorageDomain = api get viewBoxes | Where-Object name -eq $oldStorageDomain.name
                if(!$newStorageDomain){
                    Write-Host "Storage Domain $($oldStorageDomain.name) not found" -ForegroundColor Yellow
                    exit
                }
            }
        }

        # check for target policy
        if($newPolicyName){
            $oldPolicy.name = $newPolicyName
        }
        $newPolicy = (api get -v2 data-protect/policies).policies | Where-Object name -eq $oldPolicy.name
        if(!$newPolicy){
            Write-Host "Policy $($oldPolicy.name) not found" -ForegroundColor Yellow
            exit
        }
        apiauth -vip $sourceCluster -username $sourceUser -domain $sourceDomain -passwd $sourcePassword -tenant $tenant -quiet
    }

    # gather more old job details
    if(!$cleanupSourceObjectsAndExit){
        "Migrating '$jobName' from $sourceCluster to $targetCluster...`n"
    }
    $oldSources = api get protectionSources?environments=kGenericNas

    $objectList = $job.genericNasParams.objects
 
    # identify servers to migrate
    $mountPointsToMigrate = @()
    $objectsToMigrate = @{}

    foreach($mountPoint in $oldSources.nodes){
        $mountPointName = $mountPoint.protectionSource.name
        if($mountPoint.protectionSource.id -in $objectList.id){
            $objectsToMigrate[$mountPoint.protectionSource.id] = $mountPoint
            $mountPointsToMigrate = @($mountPointsToMigrate + $mountPointName | Sort-Object -Unique)
        }
    }

    # clean up source cluster
    if($cleanupSourceObjects -or $cleanupSourceObjectsAndExit){
        if($cleanupSourceObjectsAndExit){
            ""
        }
        "    Deleting old protection group..."
        if($deleteOldSnapshots){
            $delete = 'true'
        }else{
            $delete = 'false'
        }
        $null = api delete -v2 "data-protect/protection-groups/$($job.id)?deleteSnapshots=$delete"
        $rootNodes=api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false&environments=kGenericNas"
        foreach($mountPoint in $mountPointsToMigrate){
            "    Unregistering $mountPoint..."
            $rootNode = $rootNodes.rootNodes | Where-Object {$_.rootNode.name -eq $mountPoint}
            $null = api delete protectionSources/$($rootNode.rootNode.id)
        }
        if($cleanupSourceObjectsAndExit){
            "`nCleanup Complete`n"
            exit
        }
    }else{
        # pause old job
        "    Pausing old job..."
        $pauseParams = @{
            "action" = "kPause";
            "ids" = @(
                $job.id
            )
        }
        $null = api post -v2 data-protect/protection-groups/states $pauseParams
        
        # rename old job
        if($renameOldJob){
            if(!$oldJobSuffix){
                $oldJobSuffix = (Get-Date).ToString('yyyy-MM-dd')
            }
            $job.name = "$($job.name)-$oldJobSuffix"
            "    Renaming old job to ""$($job.name)"""
            $null = api put -v2 data-protect/protection-groups/$($job.id) $job
        }
    }

    # connect to target cluster
    apiauth -vip $targetCluster -username $targetUser -domain $targetDomain -passwd $targetPassword -tenant $tenant -quiet

    # update object IDs
    $newSources = api get protectionSources?environments=kGenericNas
    $newObjectList = @()
    foreach($objectItem in $objectList){
        $foundSource = $False
        $newItem = $objectItem
        $oldInfo = $objectsToMigrate[$($objectItem.id)]
        foreach($mountPoint in $newSources.nodes){
            $mountPointName = $mountPoint.protectionSource.name
            if($oldInfo.protectionSource.name -eq $mountPointName){
                $newItem.id = $mountPoint.protectionSource.id
                $foundSource = $True
            }
        }
        if(!$foundSource){
            $newSource = @{
                "environment" = "kGenericNas";
                "genericNasParams" = @{
                    "description" = $oldInfo.protectionSource.nasProtectionSource.description;
                    "mode" = $oldInfo.protectionSource.nasProtectionSource.protocol;
                    "mountPoint" = $oldInfo.protectionSource.nasProtectionSource.mountPath;
                    "skipValidation" = $true
                }
            }
            if($oldInfo.protectionSource.nasProtectionSource.protocol -eq 'kCifs1'){
                $newSource.genericNasParams['smbMountCredentials'] = @{
                    "username" = "$($oldInfo.registrationInfo.nasMountCredentials.domain)\$($oldInfo.registrationInfo.nasMountCredentials.username)";
                    "password" = ""
                }
                if($smbUsername){
                    $newSource.genericNasParams.smbMountCredentials.username = $smbUsername
                }
                if($smbPassword){
                    $newSource.genericNasParams.smbMountCredentials.password = $smbPassword
                }else{
                    if($newSource.genericNasParams.smbMountCredentials.username -in $smbPasswords.Keys){
                        $newSource.genericNasParams.smbMountCredentials.password = $smbPasswords[$newSource.genericNasParams.smbMountCredentials.username]
                    }else{
                        # prompt for SMB password
                        $pass1 = '1'
                        $pass2 = '2'
                        while($pass1 -ne $pass2){
                            $secureString = Read-Host -Prompt "    Enter password for $($newSource.genericNasParams.smbMountCredentials.username)" -AsSecureString
                            $pass1 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
                            $secureString = Read-Host -Prompt "    Confirm password for $($newSource.genericNasParams.smbMountCredentials.username)" -AsSecureString
                            $pass2 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
                        }
                        $newSource.genericNasParams.smbMountCredentials.password = $pass1
                        $smbPasswords[$newSource.genericNasParams.smbMountCredentials.username] = $pass1                        
                    }
                }
            }
            Write-Host "    Registering $($oldInfo.protectionSource.nasProtectionSource.mountPath)"
            $newSourceObj = api post -v2 data-protect/sources/registrations $newSource
            $newItem.id = $newSourceObj.id
        }
        $newObjectList = @($newObjectList + $newItem)
    }
    $job.genericNasParams.objects = $newObjectList

    if($newStorageDomain -eq $null){
        $job.storageDomainId = $null
    }else{
        $job.storageDomainId = $newStorageDomain.id
    }
    $job.policyId = $newPolicy.id

    # pause new job
    if($pauseNewJob){
        $job.isPaused = $True
    }else{
        $job.isPaused = $false
    }

    # create new job
    $job.name = $newJobName
    "    Creating job '$newJobName' on $targetCluster..."
    $newjob = api post -v2 data-protect/protection-groups $job
    "`nMigration Complete`n"
}else{
    Write-Host "Job $jobName not found" -ForegroundColor Yellow
}
