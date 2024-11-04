# usage: 
# ./restoreADobjects.ps1 -vip mycluster `
#                        -username myuser `
#                        -domain mydomain.net `
#                        -objectName msmith, server1 `
#                        -adUser 'mydomain.net\myuser' `
#                        -adPasswd swordfish `
#                        -domainController dc01.mydomain.net `
#                        -ignoreErrors `
#                        -runId 49918 `
#                        -objectList ./adobjects.txt

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,      # Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, # Cohesity username
    [Parameter()][string]$domain = 'local',          # Cohesity user domain name
    [Parameter(Mandatory = $True)][string]$domainController, # Domain controller used in backup
    [Parameter()][array]$objectName,    # object to restore (comma separated)
    [Parameter()][string]$objectList,   # objects to restore (text file, one object per line)
    [Parameter()][Int64]$runId,         # runId for restore (use latest run if omitted) 
    [Parameter()][string]$adUser,       # AD user for mounting AD backup
    [Parameter()][string]$adPasswd,     # AD password for mounting AD backup
    [Parameter()][Int64]$adPort = 9001, # port to use for AD mount
    [Parameter()][switch]$ignoreErrors, # don't wait to confirm successful object restore
    [Parameter()][switch]$showVersions, # show runIds/dates
    [Parameter()][switch]$reportDifferences
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$finishedStates = @('kSuccess','kFailed','kCanceled', 'kFailure')

# gather object names
$objectNames = @()
if($objectList -and (Test-Path $objectList -PathType Leaf)){
    $objectNames += Get-Content $objectList | Where-Object {$_ -ne ''}
}elseif($objectList){
    Write-Warning "File $objectList not found!"
    exit 1
}
foreach($obj in $objectName){
    $objectNames += $obj
}
$objectNames = $objectNames | Sort-Object -Unique
if((! $showVersions) -and (! $reportDifferences) -and $objectNames.Length -eq 0){
    Write-Host "No objects selected for restore"
    exit 1
}

# find domain controller
$searchResult = api get "/searchvms?entityTypes=kAD&vmName=$domainController"
if(! $searchResult.vms){
    Write-Host "Domain Controller not found" -ForegroundColor Yellow
    exit 1
}else{
    $doc = $searchResult.vms[0].vmDocument
    if($showVersions){
        # show available versions and exit
        $doc.versions | Select-Object -Property @{label='runId'; expression={$_.instanceId.jobInstanceId}}, @{label='runDate'; expression={usecsToDate $_.instanceId.jobStartTimeUsecs}}
        exit 0
    }
    # prompt for AD credentials
    if(! $adUser){
        $adUser = Read-Host -Prompt "Enter AD User (e.g. mydomain.net\myuser)"
    }
    if(! $adPasswd){
        $secureString = Read-Host -Prompt "Enter password for $adUser" -AsSecureString
        $adPasswd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $secureString ))
    }
    if($runId){
        # select version with matching runId
        $version = ($doc.versions | Where-Object {$_.instanceId.jobInstanceId -eq $runId})
        if(! $version){
            Write-Host "Job run ID $runId not found" -ForegroundColor Yellow
            exit 1
        }
    }else{
        # select latest version
        $version = $doc.versions[0]
    }
    $dcName = $doc.objectId.entity.displayName
    # mount AD backup
    $mountTaskDate = (get-date).ToString('yyyy-MM-dd_HH-mm-ss')
    $mountTaskName = "Recover-$($dcName)_$mountTaskDate"
    $mountParams = @{
        "name"                      = $mountTaskName;
        "applicationEnvironment"    = "kAD";
        "applicationRestoreObjects" = @(
            @{
                "applicationServerId" = $doc.objectId.entity.id;
                "adRestoreParameters" = @{
                    "port"        = $adPort;
                    "credentials" = @{
                        "username" = $adUser;
                        "password" = $adPasswd
                    }
                };
                "targetHostId"        = $doc.objectId.entity.parentId
            }
        );
        "hostingProtectionSource"   = @{
            "environment"        = "kAD";
            "jobId"              = $doc.objectId.jobId;
            "jobUid"             = @{
                "clusterId"            = $doc.objectId.jobUid.clusterId;
                "clusterIncarnationId" = $doc.objectId.jobUid.clusterIncarnationId;
                "id"                   = $doc.objectId.jobUid.objectId
            };
            "jobRunId"           = $version.instanceId.jobInstanceId;
            "protectionSourceId" = $doc.objectId.entity.parentId;
            "startedTimeUsecs"   = $version.instanceId.jobStartTimeUsecs;
            "sourceName"         = ""
        }
    }
    Write-Host "Mounting AD Backup..."
    $restoreTask = api post restore/applicationsRecover $mountParams

    # wait for mount completion
    if($restoreTask.id){
        $taskId = $restoreTask.id
        Start-Sleep 5
        $restoreTask = api get "/restoretasks/$taskId"
        while($restoreTask[0].restoreTask.performRestoreTaskState.base.publicStatus -notin $finishedStates){
            Start-Sleep 2
            $restoreTask = api get "/restoretasks/$taskId"
        }
        if($restoreTask[0].restoreTask.performRestoreTaskState.base.publicStatus -ne 'kSuccess'){
            Write-Host "Mount of AD Backup Failed" -ForegroundColor Yellow
            exit 1
        }else{
            $adTopology = api get "restore/adDomainRootTopology?restoreTaskId=$taskId"
            $dn = $adTopology[0].distinguishedName
            if($reportDifferences){
                $offset = 0
                Write-Host "Gathering differences...`n"
                """Display Name"",""Distinguished Name"",""Object Class"",""Status"",""Flags""" | Out-File -FilePath "adDifferences.csv" -Encoding utf8
                while($True){
                    $adobj = api get "restore/adObjects?restoreTaskId=$taskId&subtreeSearchScope=true&searchBaseDn=$dn&recordOffset=$offset&numObjects=101&filter=&excludeSystemProperties=true&compareObjects=true"
                    $objCount = $adobj.Count
                    $diffObjects = $adobj | Where-Object {'kEqual' -notin $_.searchResultFlags}
                    foreach($diffObject in $diffObjects){
                        Write-Host "$($diffObject.distinguishedName)"
                        if($diffObject.destinationGuid){
                            $status = 'Different'
                        }else{
                            $status = 'Missing'
                        }
                        """{0}"",""{1}"",""{2}"",""{3}"",""{4}""" -f $diffObject.displayName, $diffObject.distinguishedName, $diffObject.objectClass, $status, ($diffObject.searchResultFlags -join '; ') | Out-File -FilePath "adDifferences.csv" -Append
                    }
                    if($objCount -lt 101){
                        Write-Host ""
                        break
                    }
                    $offset += 101
                    Write-Host "    $offset"
                }
                Write-Host "Difference Report saved to adDifferences.csv"
            }else{
                foreach($obj in $objectNames){

                    # find object in backup
                    $adSearch = api get "restore/adObjects?restoreTaskId=$taskId&subtreeSearchScope=true&searchBaseDn=$dn&recordOffset=0&numObjects=16&filter=$obj&excludeSystemProperties=true&compareObjects=false"
                    $objectGuid = $adSearch[0].sourceGuid
                    if($objectGuid){
    
                        # find object in live AD
                        $attributeQuery = @{                          
                            "restoreTaskId"           = $taskId;          
                            "excludeSysAttributes"    = $true;
                            "filterNullValAttributes" = $true;
                            "filterSameValAttributes" = $false;
                            "quickCompare"            = $true;
                            "allowEmptyDestGuids"     = $true;
                            "guidPairs"               = @(
                                @{
                                    "sourceGuid" = $objectGuid
                                }
                            )
                        }
    
                        $targetStatus = api post restore/adObjectAttributes $attributeQuery
    
                        if('kDestinationNotFound' -in $targetStatus[0].adObjectFlags){
                            # restore object
                            $restoreParams = @{
                                "restoreTaskId" = $taskId;
                                "adOptions"     = @{
                                    "type"             = "kObjects";
                                    "objectParameters" = @{
                                        "objectGuids"        = @(
                                            $objectGuid
                                        );
                                        "leaveStateDisabled" = $false
                                    }
                                }
                            }
                            Write-Host "Restoring object $obj..."
                            $null = api put restore/recover $restoreParams
                            if(! $ignoreErrors){
                                # monitor for successful object restore
                                $objectRestoreStatus = 'kRunning'
                                while($objectRestoreStatus -notin $finishedStates){
                                    Start-Sleep 1
                                    $restoreTask = api get "/restoretasks/$taskId"
                                    $subTask = $restoreTask.restoreTask.restoreSubTaskWrapperProtoVec | Where-Object {$objectGuid -in $_.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.adRestoreParams.adUpdateOptions.objectParam.guidVec}
                                    $objectRestoreStatus = $subTask.performRestoreTaskState.base.publicStatus
                                }
                                if($objectRestoreStatus -ne 'kSuccess'){
                                    $errorMsg = $subTask.performRestoreTaskState.base.error.errorMsg
                                    Write-Host "$errorMsg" -ForegroundColor Yellow
                                }
                            }
                        }else{
                            # restore properties
                            $destinationGuid = $targetStatus[0].destinationGuid
                            $restoreParams = @{
                                "restoreTaskId" = $taskId;
                                "adOptions"     = @{
                                    "type"                      = "kObjectAttributes";
                                    "objectAttributeParameters" = @{
                                        "adGuidPairs"             = @(
                                            @{
                                                "source"      = $objectGuid;
                                                "destination" = $destinationGuid
                                            }
                                        );
                                        "mergeMultiValProperties" = $false;
                                        "ldapProperties"          = @()
                                    }
                                }
                            }
                            Write-Host "Restoring object $obj..."
                            $null = api put restore/recover $restoreParams
                            if(! $ignoreErrors){
                                # monitor for successful object restore
                                $objectRestoreStatus = 'kRunning'
                                while($objectRestoreStatus -notin $finishedStates){
                                    Start-Sleep 1
                                    $restoreTask = api get "/restoretasks/$taskId"
                                    $subTask = $restoreTask.restoreTask.restoreSubTaskWrapperProtoVec | Where-Object {$objectGuid -in $_.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.adRestoreParams.adUpdateOptions.objectAttributesParam.guidpairVec[0]}
                                    $objectRestoreStatus = $subTask.performRestoreTaskState.base.publicStatus
                                }
                                if($objectRestoreStatus -ne 'kSuccess'){
                                    $errorMsg = $subTask.performRestoreTaskState.base.error.errorMsg
                                    Write-Host "$errorMsg" -ForegroundColor Yellow
                                }
                            }
                        }
                    }else{
                        Write-Host "Object $obj not found" -ForegroundColor Yellow
                    }
                }
            }


            # unmount AD backup
            Write-Host "Unmounting AD Backup..."
            $null = api post "/destroyclone/$taskId"
            exit 0
        }
    }else{
        Write-Host "Mount of AD Backup Failed" -ForegroundColor Yellow
        exit 1
    }
}
