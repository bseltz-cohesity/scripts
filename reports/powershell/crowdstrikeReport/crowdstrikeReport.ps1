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
    [Parameter()][string]$matchPath = '/Windows/System32/drivers/CrowdStrike/C-00000291',  # '/scripts/python/build/archiveEndOfMonth/localpycs/pyimod0'
    [Parameter()][int]$objectCount = 100,
    [Parameter()][switch]$statFiles
)

$startPath = $matchPath.subString(0,$matchPath.lastIndexOf('/'))

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

function listdir($dirPath, $instance, $volumeInfoCookie=$null, $volumeName=$null, $cookie=$null){
    $useLibrarian = $false
    $statfile = $false
    if($statFiles){
        $statfile = $True
    }
    $thisDirPath = [System.Web.HttpUtility]::UrlEncode($dirPath).Replace('%2f%2f','%2F')
    if($cookie){
        if($null -ne $volumeName){
            $dirList = api get "/vm/directoryList?$instance&useLibrarian=$useLibrarian&statFileEntries=$statfile&volumeInfoCookie=$volumeInfoCookie&cookie=$cookie&volumeName=$volumeName&dirPath=$thisDirPath" -quiet
        }else{
            $dirList = api get "/vm/directoryList?$instance&useLibrarian=$useLibrarian&statFileEntries=$statfile&cookie=$cookie&dirPath=$thisDirPath" -quiet
        }
    }else{
        if($null -ne $volumeName){
            $dirList = api get "/vm/directoryList?$instance&useLibrarian=$useLibrarian&statFileEntries=$statfile&volumeInfoCookie=$volumeInfoCookie&volumeName=$volumeName&dirPath=$thisDirPath" -quiet
        }else{
            $dirList = api get "/vm/directoryList?$instance&useLibrarian=$useLibrarian&statFileEntries=$statfile&dirPath=$thisDirPath" -quiet
        }
    }
    if($dirList.PSObject.Properties['entries'] -and $dirList.entries.Count -gt 0){
        $Script:filesFound = $True
        foreach($entry in $dirList.entries | Sort-Object -Property name){
            # "$dirPath/$($entry.name)"
            if($entry.type -eq 'kDirectory'){
                $nextDirPath = "$dirPath/$($entry.name)"
                if($null -ne $volumeName){
                    $shortPath = "$($nextDirPath.substring(1))"
                }else{
                    $shortPath = "$($nextDirPath.substring(3))"
                }
                if($shortPath -gt $matchPath){
                    break
                }
                if($matchPath -match $shortPath){
                    listdir "$dirPath/$($entry.name)" $instance $volumeInfoCookie $volumeName
                }
            }else{
                $Script:fileCount += 1
                if($entry.fullPath -match $matchPath){
                    # $mtime = usecsToDate $entry.fstatInfo.mtimeUsecs
                    $script:fileList = @($script:fileList + @{'path' = $entry.fullPath; 'mtime' = $entry.fstatInfo.mtimeUsecs})
                }
            }
        }
    }
    if($dirlist.PSObject.Properties['cookie']){
        listdir "$dirPath" $instance $volumeInfoCookie $volumeName $dirlist.cookie
    }
}

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "$($cluster.name)-$dateString-CrowdStrikeReport.csv"

# headings
if($statFiles){
    """Object Name"",""Environment"",""Protected"",""Useful Protection Group"",""Latest Backup"",""Latest File"",""Last Modified Date""" | Out-File -FilePath $outfileName -Encoding utf8
}else{
    """Object Name"",""Environment"",""Protected"",""Useful Protection Group"",""Latest Backup"",""Latest File""" | Out-File -FilePath $outfileName -Encoding utf8
}

$volumeTypes = @(1, 6, 29)

$paginationCookie = 0

While($True){
    $search = api get -v2 "data-protect/search/objects?osTypes=kWindows&paginationCookie=$paginationCookie&count=$objectCount"
    foreach($obj in $search.objects){
        "{0} ({1})" -f $obj.name, $obj.environment
        $protectionGroup = ''
        $protected = $false
        $script:fileList = @('')
        $latestFile = ''
        $usefulProtectionGroup = ''
        $latestBackup = ''
        $lastMtime = ''
        foreach($protectionInfo in $obj.objectProtectionInfos){
            foreach($pg in $protectionInfo.protectionGroups){
                $protected = $True
                $protectionGroup = $pg.name
                $v1JobId = ($pg.id -split ':')[2]
                $searchResults = api get "/searchvms?vmName=$($obj.name)&jobIds=$v1JobId"
                $searchResults = $searchResults.vms | Where-Object {$_.vmDocument.objectName -eq $obj.name}
                if(! $searchResults){
                    continue
                }
                $searchResult = ($searchResults | sort-object -property @{Expression={$_.vmDocument.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]
                $doc = $searchResult.vmDocument
                $version = $doc.versions[0]
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
                # "    ** $($doc.backupType)"
                if($backupType -in $volumeTypes){
                    $volumeList = api get "/vm/volumeInfo?$instance"
                    if($volumeList.PSObject.Properties['volumeInfos']){
                        $volumeInfoCookie = $volumeList.volumeInfoCookie
                        foreach($volume in $volumeList.volumeInfos | Sort-Object -Property name){
                            $volumeName = [System.Web.HttpUtility]::UrlEncode($volume.name)
                            # "-- $volumeName"
                            listdir "/$startPath" $instance $volumeInfoCookie $volumeName
                        }
                    }
                }else{
                    $driveLetters = $doc.objectId.entity.physicalEntity.volumeInfoVec.mountPointVec | Where-Object {$_ -ne $null}
                    foreach($driveLetter in $driveLetters){
                        $shortDriveLetter = $driveLetter.subString(0,1)
                        listdir "/$($shortDriveLetter)$($startPath)" $instance
                        $latestFile = @($script:fileList | Sort-Object -Property {$_.mtime})[-1]
                        if($latestFile -ne ''){
                            break
                        }
                    }
                    # listdir '/' $instance
                }
                $lastMtime = ''
                $latestFile = @($script:fileList | Sort-Object -Property {$_.mtime})[-1]
                if($latestFile -ne ''){
                    if($statFiles){
                        "    {0} ({1})" -f $latestFile.path, (usecsToDate $latestFile.mtime)
                    }else{
                        "    {0}" -f $latestFile.path
                    }
                }
                if($latestFile -ne '' -and $usefulProtectionGroup -eq ''){
                    $usefulProtectionGroup = $protectionGroup
                    $latestBackup = usecsToDate $version.instanceId.jobStartTimeUsecs
                    if($statFiles){
                        $lastMtime = usecsToDate $latestFile.mtime
                    }
                }
            }
        }
        """$($obj.name)"",""$($obj.environment)"",""$protected"",""$usefulProtectionGroup"",""$latestBackup"",""$($latestFile.path)"",""$lastMtime""" | Out-File -FilePath $outfileName -Append
    }
    if($search.count -eq $search.paginationCookie){
        break
    }else{
        $paginationCookie = $search.paginationCookie
    }
}

"`nOutput saved to $outfilename`n"
