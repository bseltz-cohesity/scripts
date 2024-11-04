# version 2024.06.05
# usage: ./backedUpFileList.ps1 -vip mycluster \
#                               -username myuser \
#                               -domain mydomain.net \
#                               -sourceServer server1.mydomain.net \
#                               -jobName myjob \
#                               [ -showVersions ]
#                               [ -runId 123456 ] 
#                               [ -fileDate '2020-06-29 12:00:00' ]

### process commandline arguments
[CmdletBinding(PositionalBinding=$False)]
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
    [Parameter(Mandatory = $True)][array]$sourceServer, # source server
    [Parameter(Mandatory = $True)][string]$jobName, # narrow search by job name
    [Parameter()][switch]$showVersions,
    [Parameter()][switch]$listFiles,
    [Parameter()][datetime]$start,
    [Parameter()][datetime]$end,
    [Parameter()][Int64]$runId,
    [Parameter()][datetime]$fileDate,
    [Parameter()][string]$startPath = '/',
    [Parameter()][switch]$noIndex,
    [Parameter()][switch]$forceIndex,
    [Parameter()][switch]$showStats,
    [Parameter()][Int64]$newerThan = 0
)

if($noIndex){
    $useLibrarian = $False
}else{
    $useLibrarian = $True
}

if($showStats -or $newerThan -gt 0){
    $statfile = $True
}else{
    $statfile = $False
}

$daysAgo = (get-Date).AddDays(-$newerThan)

$volumeTypes = @(1, 6)

### source the cohesity-api helper code
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


function listdir($dirPath, $instance, $volumeInfoCookie=$null, $volumeName=$null, $cookie=$null){
    $thisDirPath = [System.Web.HttpUtility]::UrlEncode($dirPath).Replace('%2f%2f','%2F')
    if($cookie){
        if($null -ne $volumeName){
            $dirList = api get "/vm/directoryList?$instance&useLibrarian=$useLibrarian&statFileEntries=$statfile&volumeInfoCookie=$volumeInfoCookie&cookie=$cookie&volumeName=$volumeName&dirPath=$thisDirPath"
        }else{
            $dirList = api get "/vm/directoryList?$instance&useLibrarian=$useLibrarian&statFileEntries=$statfile&cookie=$cookie&dirPath=$thisDirPath"
        }
    }else{
        if($null -ne $volumeName){
            $dirList = api get "/vm/directoryList?$instance&useLibrarian=$useLibrarian&statFileEntries=$statfile&volumeInfoCookie=$volumeInfoCookie&volumeName=$volumeName&dirPath=$thisDirPath"
        }else{
            $dirList = api get "/vm/directoryList?$instance&useLibrarian=$useLibrarian&statFileEntries=$statfile&dirPath=$thisDirPath"
        }
    }
    if($dirList.PSObject.Properties['entries'] -and $dirList.entries.Count -gt 0){
        $Script:filesFound = $True
        foreach($entry in $dirList.entries | Sort-Object -Property name){
            if($entry.type -eq 'kDirectory'){
                listdir "$dirPath/$($entry.name)" $instance $volumeInfoCookie $volumeName
            }else{
                if($statfile){
                    $filesize = $entry.fstatInfo.size
                    $mtime = usecsToDate $entry.fstatInfo.mtimeUsecs
                    if($mtime -ge $daysAgo -or $newerThan -eq 0){
                        $Script:fileCount += 1
                        "{0} ({1}) [{2} bytes]" -f $entry.fullPath, $mtime, $filesize | Tee-Object -FilePath $outputfile -Append
                    }
                }else{
                    $Script:fileCount += 1
                    "{0}" -f $entry.fullPath | Tee-Object -FilePath $outputfile -Append  
                }
            }
        }
    }
    if($dirlist.PSObject.Properties['cookie']){
        listdir "$dirPath" $instance $volumeInfoCookie $volumeName $dirlist.cookie
    }
}

function showFiles($doc, $version){
    if($version.numEntriesIndexed -eq 0){
        $useLibrarian = $False
    }else{
        if($version.indexingStatus -ne 2){
            $useLibrarian = $False
        }else{
            $useLibrarian = $True
        }
    }
    if($forceIndex -and $version.indexingStatus -eq 2){
        $useLibrarian = $True
    }
    if($noIndex){
        $useLibrarian = $False
    }
    if($newerThan -gt 0){
        Write-Host "`nSearching for files added/modified in the past $newerThan days...`n"
    }
    $Script:filesFound = $False
    $Script:fileCount = 0
    $versionDate = (usecsToDate $version.instanceId.jobStartTimeUsecs).ToString('yyyy-MM-dd_hh-mm-ss')
    $sourceServerString = $sourceServer.Replace('\','-').Replace('/','-')
    $outputfile = $(Join-Path -Path $PSScriptRoot -ChildPath "backedUpFiles-$($version.instanceId.jobInstanceId)-$($sourceServerString)-$versionDate.txt")
    $null = Remove-Item -Path $outputfile -Force -ErrorAction SilentlyContinue
    if(! $version.instanceId.PSObject.PRoperties['attemptNum']){
        $attemptNum = 0
    }else{
        $attemptNum = $version.instanceId.attemptNum
    }
    $instance = "attemptNum={0}&clusterId={1}&clusterIncarnationId={2}&entityId={3}&jobId={4}&jobInstanceId={5}&jobStartTimeUsecs={6}&jobUidObjectId={7}" -f
                $attemptNum,
                $doc.objectId.jobUid.clusterId,
                $doc.objectId.jobUid.clusterIncarnationId,
                $doc.objectId.entity.id,
                $doc.objectId.jobId,
                $version.instanceId.jobInstanceId,
                $version.instanceId.jobStartTimeUsecs,
                $doc.objectId.jobUid.objectId
    
    $backupType = $doc.backupType
    if($backupType -in $volumeTypes){
        $volumeList = api get "/vm/volumeInfo?$instance&statFileEntries=$statfile"
        if($volumeList.PSObject.Properties['volumeInfos']){
            $volumeInfoCookie = $volumeList.volumeInfoCookie
            foreach($volume in $volumeList.volumeInfos | Sort-Object -Property name){
                $volumeName = [System.Web.HttpUtility]::UrlEncode($volume.name)
                listdir $startPath $instance $volumeInfoCookie $volumeName
            }
        }
    }else{
        listdir $startPath $instance
    }
    if($Script:filesFound -eq $False){
        "No Files Found" | Tee-Object -FilePath $outputfile -Append
    }else{
        "`n$($Script:fileCount) files found" | Tee-Object -FilePath $outputfile -Append
    }
}

$sourceServers = $sourceServer
foreach($sourceServer in $sourceServers){
    Write-Host "`n============================`n $sourceServer`n============================`n"
    $searchResults = api get "/searchvms?entityTypes=kView&entityTypes=kAcropolis&entityTypes=kAWS&entityTypes=kAWSNative&entityTypes=kAWSSnapshotManager&entityTypes=kAzure&entityTypes=kAzureNative&entityTypes=kFlashBlade&entityTypes=kGCP&entityTypes=kGenericNas&entityTypes=kHyperV&entityTypes=kHyperVVSS&entityTypes=kIsilon&entityTypes=kKVM&entityTypes=kNetapp&entityTypes=kPhysical&entityTypes=kVMware&vmName=$sourceserver"
    $searchResults = $searchResults.vms | Where-Object {$_.vmDocument.objectName -eq $sourceServer}

    if(!$searchResults){
        Write-Host "no backups found for $sourceServer" -ForegroundColor Yellow
        continue
    }

    # narrow search by job name
    $altJobName = "Old Name: $jobName"
    $altJobName2 = "$jobName \(Old Name:"
    $searchResults = $searchResults | Where-Object {($_.vmDocument.jobName -eq $jobName) -or ($_.vmDocument.jobName -match $altJobName) -or ($_.vmDocument.jobName -match $altJobName2)}

    if(!$searchResults){
        Write-Host "$sourceServer is not protected by $jobName" -ForegroundColor Yellow
        continue
    }

    $searchResult = ($searchResults | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

    $doc = $searchResult.vmDocument

    # show versions
    if($showVersions -or $start -or $end -or $listFiles){
        if($start){
            $doc.versions = $doc.versions | Where-Object {$start -le (usecsToDate ($_.snapshotTimestampUsecs))}
        }
        if($end){
            $doc.versions = $doc.versions | Where-Object {$end -ge (usecsToDate ($_.snapshotTimestampUsecs))}
        }
        if($listFiles){
            foreach($version in $doc.versions){
                Write-Host "`n=============================="
                Write-Host "   runId: $($version.instanceId.jobInstanceId)"
                write-host " runDate: $(usecsToDate $version.instanceId.jobStartTimeUsecs)"
                Write-Host "==============================`n"
                if($version.numEntriesIndexed -eq 0){
                    $useLibrarian = $False
                }
                showFiles $doc $version
            }
        }else{
            $doc.versions | Select-Object -Property @{label='runId'; expression={$_.instanceId.jobInstanceId}}, @{label='runDate'; expression={usecsToDate $_.instanceId.jobStartTimeUsecs}}
        }
        continue
    }

    $Script:filesFound = $False

    # select version
    if($runId){
        # select version with matching runId
        $version = ($doc.versions | Where-Object {$_.instanceId.jobInstanceId -eq $runId})
        if(! $version){
            Write-Host "Job run ID $runId not found" -ForegroundColor Yellow
            continue
        }
        if($version.numEntriesIndexed -eq 0){
            $useLibrarian = $False
        }
        showFiles $doc $version
    }elseif($fileDate){
        # select version just after requested date
        $version = ($doc.versions | Where-Object {$fileDate -le (usecsToDate ($_.snapshotTimestampUsecs))})[-1]
        if(! $version){
            $version = $doc.versions[0]
        }
        if($version.numEntriesIndexed -eq 0){
            $useLibrarian = $False
        }
        showFiles $doc $version
    }else{
        # just use latest version
        $version = $doc.versions[0]
        if($version.numEntriesIndexed -eq 0){
            $useLibrarian = $False
        }
        showFiles $doc $version
    }
}
