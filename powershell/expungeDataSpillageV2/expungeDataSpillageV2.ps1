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
    [Parameter()][string]$clusterName = $null,
    [Parameter()][array]$objectName,
    [Parameter()][string]$objectList,   
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][string]$search,
    [Parameter()][int]$numRuns = 1000,
    [Parameter()][switch]$exactMatch,
    [Parameter()][switch]$showVersions,
    [Parameter()][int]$olderThan = 0,
    [Parameter()][int]$newerThan = 0,
    [Parameter()][switch]$expunge
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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

if($olderThan -gt 0){
    $olderThanUsecs = timeAgo $olderthan days
}

if($newerThan -gt 0){
    $newerThanUsecs = timeAgo $newerThan days
}

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "spillage-$($cluster.name)-$dateString.csv"

$remoteClusters = api get remoteClusters

# headings
"Job Name,Object Name,Backup Date,Target,Expunged,File Path" | Out-File -FilePath $outfileName

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

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $false)
$objectNames = @(gatherList -Param $objectName -FilePath $objectList -Name 'jobs' -Required $false)

$searchParams = @{
    "fileParams" = @{
        "searchString" = "$search";
        "sourceEnvironments" = @(
            "kAcropolis";
            "kAWS";
            "kAzure";
            "kGCP";
            "kHyperV";
            "kKVM";
            "kVMware";
            "kPhysical";
            "kNetapp";
            "kIsilon";
            "kGenericNas";
            "kFlashBlade";
            "kGPFS";
            "kElastifile";
            "kPhysicalFiles";
            "kView"
        );
        "objectIds" = @()
    };
    "objectType" = "Files"
}

$searchResults = api post -v2 data-protect/search/indexed-objects $searchParams
if($searchResults.files){
    if($exactMatch){
        $files = $searchResults.files | Where-Object name -eq $search
    }else{
        $files = $searchResults.files | Where-Object name -match $search
    }
    # filter on job name
    if($jobNames.Count -gt 0){
        $files = $files | Where-Object {$_.protectionGroupName -in $jobNames}
    }
    # filter on object name
    if($objectNames.Count -gt 0){
        $files = $files | Where-Object {$_.sourceInfo.name -in $objectNames}
    }

    # output file list
    $files | Select-Object -Property @{label='jobName'; expression={$_.protectionGroupName}}, @{label='objectName'; expression={$_.sourceInfo.name}}, @{label='fileName'; expression={$_.name}}, @{label='filePath'; expression={$_.path}} | Out-String | ForEach-Object{Write-Host $_}

    if($showVersions -or $expunge){
        Write-Host "Version info:"
    }
    
    foreach($file in $files){
        $name = $file.name
        $path = $file.path
        $fullPath = Join-Path -Path $path -ChildPath $name
        $encodedPath = [System.Web.HttpUtility]::UrlEncode($fullPath).Replace('%2f%2f','%2F')
        $protectionGroupId = $file.protectionGroupId
        $v1JobId = $protectionGroupId.split(':')[2]
        $protectionGroupName = $file.protectionGroupName
        $objectId = $file.sourceInfo.id
        $objectName = $file.sourceInfo.name
        $objectType = $file.sourceInfo.objectType.subString(1)
        if($showVersions -or $expunge){
            Write-Host "`n==================================================="
            Write-Host "   Job Name: $protectionGroupName"
            Write-Host "Object Name: $objectName ($objectType)"
            Write-Host "  Full Path: $fullPath"
            Write-Host "===================================================`n"
        }
        $snapshots = api get -v2 "data-protect/objects/$objectId/protection-groups/$protectionGroupId/indexed-objects/snapshots?indexedObjectName=$encodedPath&includeIndexedSnapshotsOnly=false"
        if($olderThan -gt 0){
            $snapshots.snapshots = $snapshots.snapshots | Where-Object {$_.snapshotTimestampUsecs -le $olderThanUsecs}
        }
        if($newerThan -gt 0){
            $snapshots.snapshots = $snapshots.snapshots | Where-Object {$_.snapshotTimestampUsecs -ge $newerThanUsecs}
        }
        foreach($snapshot in $snapshots.snapshots){
            $timeStamp = $snapshot.snapshotTimestampUsecs
            # archive
            if($snapshot.PSObject.Properties['externalTargetInfo']){
                foreach($externalTarget in $snapshot.externalTargetInfo){
                    $targetName = $externalTarget.targetName
                    $targetId = $externalTarget.targetId
                    $targetType = "k$($externalTarget.targetType)"
                    if($showVersions -and $expunge){
                        $jobRunParams = @{
                            "jobRuns" = @(
                                @{
                                    "copyRunTargets" = @(
                                        @{
                                            "archivalTarget" = @{
                                                "vaultId" = $targetId;
                                                "vaultName" = $targetName;
                                                "vaultType" = $targetType
                                            };
                                            "daysToKeep" = 0;
                                            "type" = "kArchival"
                                        }
                                    );
                                    "runStartTimeUsecs" = $timeStamp;
                                    "jobUid" = @{
                                        "clusterId" = $cluster.id;
                                        "clusterIncarnationId" = $cluster.incarnationId;
                                        "id" = [Int64]$v1JobId
                                    }
                                }
                            )
                        }
                        "$protectionGroupName,$objectName,$(usecsToDate $timeStamp),$targetName,Expunged,$fullPath" | Out-File -FilePath $outfileName -Append
                        Write-Host "    $(usecsToDate $timeStamp) (archive: $targetName)  ** Expunging **"
                        $null = api put protectionRuns $jobRunParams
                    }else{
                        if($showVersions){
                            "$protectionGroupName,$objectName,$(usecsToDate $timeStamp),$targetName,,$fullPath" | Out-File -FilePath $outfileName -Append
                            Write-Host "    $(usecsToDate $timeStamp) (archive: $targetName)"
                        }
                    }
                }
            # local snapshot
            }else{
                if($showVersions -and $expunge){
                    $jobRunParams = @{
                        "jobRuns" = @(
                            @{
                                "copyRunTargets" = @(
                                    @{
                                        "daysToKeep" = 0;
                                        "type" = "kLocal"
                                    }
                                );
                                "jobUid" = @{
                                    "clusterId" = $cluster.id;
                                    "clusterIncarnationId" = $cluster.incarnationId;
                                    "id" = [Int64]$v1JobId
                                };
                                "runStartTimeUsecs" = $timeStamp;
                                "sourceIds" = @(
                                    $objectId
                                )
                            }
                        )
                    }
                    "$protectionGroupName,$objectName,$(usecsToDate $timeStamp),Local,Expunged,$fullPath" | Out-File -FilePath $outfileName -Append
                    Write-Host "    $(usecsToDate $timeStamp) (local snapshot)  ** Expunging **"
                    $null = api put protectionRuns $jobRunParams
                }else{
                    if($showVersions){
                        "$protectionGroupName,$objectName,$(usecsToDate $timeStamp),Local,,$fullPath" | Out-File -FilePath $outfileName -Append
                        Write-Host "    $(usecsToDate $timeStamp) (local snapshot)"
                    }
                }
            }
        }
    }

    $policies = api get -v2 data-protect/policies
    $remoteTargetNames = $policies.policies.remoteTargetPolicy.replicationTargets.remoteTargetConfig.clusterName | Sort-Object -Unique
    Write-Host "`nThis cluster replicates to the following clusters, please run this script on these clusters as well:" -ForegroundColor Yellow
    Write-Host "`n$($remoteTargetNames -join "`n")" -ForegroundColor Yellow
}else{
    Write-Host "No search results found"
}

Write-Host "`nOutput saved to $outfilename`n"
