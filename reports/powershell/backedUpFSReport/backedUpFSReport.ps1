### process commandline arguments
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
    [Parameter()][string]$clusterName, # local or AD domain
    [Parameter()][int]$daysAgo = 0,
    [Parameter()][string]$smtpServer, # outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, # outbound smtp port
    [Parameter()][array]$sendTo, # send to address
    [Parameter()][string]$sendFrom # send from address
)

$volumeTypes = @(1, 6)
$Script:fsType = ''
$Script:useLibrarian = 'false'

$environments = @('Unknown', 'VMware', 'HyperV', 'SQL', 'View',
                  'RemoteAdapter', 'Physical', 'Pure', 'Azure', 'Netapp',
                  'Agent', 'GenericNas', 'Acropolis', 'PhysicalFiles',
                  'Isilon', 'KVM', 'AWS', 'Exchange', 'HyperVVSS',
                  'Oracle', 'GCP', 'FlashBlade', 'AWSNative', 'VCD',
                  'O365', 'O365Outlook', 'HyperFlex', 'GCPNative',
                  'AzureNative','AD', 'AWSSnapshotManager', 'Unknown', 
                  'Unknown', 'Unknown', 'Unknown', 'Unknown')

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

$cluster = api get cluster
$clusterName = $cluster.name

$today = get-date
$date = $today.ToString()
$dateString = $today.ToString("yyyy-MM-dd")

$csvFileName = "$clusterName-BackedUpFSReport-$dateString.csv"
$Global:htmlFileName = "$clusterName-BackedUpFSReport-$dateString.html"

$title = "Backed Up File System Report for $($cluster.name)"

$trColors = @('#FFFFFF;', '#F1F1F1;')

$Global:html = '<html>
<head>
    <style>
        p {
            color: #555555;
            font-family:Arial, Helvetica, sans-serif;
        }
        span {
            color: #555555;
            font-family:Arial, Helvetica, sans-serif;
        }
        

        table {
            font-family: Arial, Helvetica, sans-serif;
            color: #333333;
            font-size: 0.75em;
            border-collapse: collapse;
            width: 100%;
        }

        tr {
            border: 1px solid #F8F8F8;
            background-color: #F8F8F8;
        }

        td,
        th {
            width: 20%;
            text-align: left;
            padding: 6px;
        }
    </style>
</head>
<body>
    
    <div style="margin:15px;">
            <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAARgAAAAoCAMAAAASXRWnAAAC8VBMVE
            WXyTz///+XyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTwJ0VJ2AAAA+nRSTlMAAAECAwQFBgcICQoLDA0ODxARExQVFhcYGRobHB0eHy
            EiIyQlJicoKSorLC0uLzAxMjM0NTY3ODk6Ozw9Pj9AQUNERUZHSElKS0xNTk9QUVJTVFVWV1hZWl
            tcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9foCBgoOEhYaHiImKi4yNjo+QkZKTlJ
            WWl5iZmpucnZ6foKGio6SlpqeoqaqrrK2ur7CxsrO0tba3uLm6u7y9vr/AwcLDxMXGx8jJysvMzc
            7Q0dLT1NXW19jZ2tvc3d7f4OHi4+Xm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+drbbjAAACOZJRE
            FUaIHtWmlcVUUUv6alIgpiEGiZZIpiKu2i4obhUgipmGuihuZWiYmkRBu4JJVappaG5VJRUWrllq
            ZWivtWVuIWllHwShRI51PvnjP33pk7M1d579Gn/j8+zDnnf2b5v3tnu2g1/ocUmvuPRasx83cVu1
            zFB5endtWUCHgoM/+0y1V64sOZcXVlhMDpWXdLM+PmPnmdZTVJeLCPiL6Jd9jT6nfo2y+hH4vE/h
            Fcj6bP6uhcqxvxfYzOdsxOb6gYm39qdrRmE6bBxB2EQWHOXfLBvVvMsIqWdBEYzYvcgWRJ6nS3f5
            +/YSWXEQVeYJPqpXx5XkaaalFuOu22h2E5UVkrIadaAyXFXTwbKh1cw0J3bCgvzFO/CRWtuk3IjP
            lKYK23C7ga3IFCblPwp1HrNvUAyH1W0tRzKlIbk/OmbpbX04uNHGp1/9j6MxMMxUNSYXbqoTJWmF
            t3yCqqHGVLzJK2l8qTtoOzldBqD/C/Ra3hDgOYZKTU2awmpZgVbwG7udWGEvovHYXFHIkuYzHECN
            Pzb0VNy9g8/60KVh5X/QbwtRCajQH//GsQ5k7KCTzqQGprVrwW7HC9GOKQQMhpP30UpWiIM0XYZQ
            gcsYR50Mo9vj73vS9+sOy1Vl6A5S7auXJ53v4Lpr2Trf9LcN0utNsZ/K9Ra4iy++XGE+h3zGGQaV
            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
            8LK0YAAAAASUVORK5CYII=" style="width:180px">
        <p style="margin-top: 15px; margin-bottom: 15px;">
            <span style="font-size:1.3em;">'

$Global:html += $title
$Global:html += '</span>
<span style="font-size:1em; text-align: right; padding-right: 2px; float: right;">'
$Global:html += $date
$Global:html += '</span>
</p>
<table>
<tr style="background-color: #F1F1F1;">
    <th>Job Name</th>
    <th>Job Type</th>
    <th>Object Name</th>
    <th>Policy Name</th>
    <th>Latest Backup</th>
    <th>FS Type</th>
    <th>Path</th>
</tr>'

"Job Name,Job Type,Protected Object,Policy Name,Latest Backup Date,Run ID,FS Type,Path" | Out-File -FilePath $csvFileName

function listdir($dirPath, $instance, $volumeInfoCookie=$null, $volumeName=$null){
    $thisDirPath = $dirPath
    if($null -ne $volumeName){
        $dirList = api get "/vm/directoryList?$instance&dirPath=$thisDirPath&statFileEntries=false&volumeInfoCookie=$volumeInfoCookie&volumeName=$volumeName&useLibrarian=$($Script:useLibrarian)"
    }else{
        $dirList = api get "/vm/directoryList?$instance&dirPath=$thisDirPath&statFileEntries=false&useLibrarian=$($Script:useLibrarian)"
    }
    if($dirList.PSObject.Properties['entries']){
        foreach($entry in $dirList.entries | Sort-Object -Property name){           
            if($entry.type -eq 'kDirectory'){
                "{0} ({1}): {2} - {3}: {4}" -f $jobName, $jobType, $objectName, $lastBackup, $entry.fullPath
                "{0},{1},{2},{3},{4},{5},{6},{7}" -f $jobName, $jobType, $objectName, $policyName, $lastBackup, $runId, $Script:fsType, $entry.fullPath | Out-File -FilePath $csvFileName -Append
                if($Global:firstEntry){
                    $Global:html += '<tr style="border: 1px solid {6} background-color: {6}">
                    <td>{0}</td>
                    <td>{1}</td>
                    <td>{2}</td>
                    <td>{3}</td>
                    <td>{4}</td>
                    <td>{5}</td>
                    <td>{6}</td>
                    </tr>' -f $jobName, $jobType, $objectName, $policyName, $lastBackup, $Script:fsType, $entry.fullPath, $Global:trColor
                    $Global:firstEntry = $false
                }else{
                    $Global:html += '<tr style="border: 1px solid {2} background-color: {1}">
                    <td></td>
                    <td></td>
                    <td></td>
                    <td></td>
                    <td></td>
                    <td>{0}</td>
                    <td>{1}</td>
                    </tr>' -f $Script:fsType, $entry.fullPath, $Global:trColor
                }
            }
        }
    }
}

function showFiles($doc, $version){
    if($version.replicaInfo.replicaVec[0].target.type -eq 3){
        $Script:useLibrarian = 'true'
    }
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
        $volumeList = api get "/vm/volumeInfo?$instance&statFileEntries=false"
        if($volumeList.PSObject.Properties['volumeInfos']){
            foreach($volume in $volumeList.volumeInfos | Sort-Object -Property name){
                $Script:fsType = $volume.filesystemType
                "{0} ({1}): {2} - {3}: {4}" -f $jobName, $jobType, $objectName, $lastBackup, $volume.name
                "{0},{1},{2},{3},{4},{5},{6},{7}" -f $jobName, $jobType, $objectName, $policyName, $lastBackup, $runId, $Script:fsType, $volume.name | Out-File -FilePath $csvFileName -Append
                if($Global:firstEntry){
                    $Global:html += '<tr style="border: 1px solid {6} background-color: {6}">
                    <td>{0}</td>
                    <td>{1}</td>
                    <td>{2}</td>
                    <td>{3}</td>
                    <td>{4}</td>
                    <td>{5}</td>
                    <td>{6}</td>
                    </tr>' -f $jobName, $jobType, $objectName, $policyName, $lastBackup, $Script:fsType, $volume.name, $Global:trColor
                    $Global:firstEntry = $false
                }else{
                    $Global:html += '<tr style="border: 1px solid {2} background-color: {1}">
                    <td></td>
                    <td></td>
                    <td></td>
                    <td></td>
                    <td></td>
                    <td>{0}</td>
                    <td>{1}</td>
                    </tr>' -f $Script:fsType, $volume.name, $Global:trColor
                }
            }
        }
    }else{
        $Script:fsType = ''
        if($doc.objectId.entity.PSObject.Properties['physicalEntity']){
            $Script:fsType = 'ntfs'
            $volumeInfo = $doc.objectId.entity.physicalEntity.volumeInfoVec | Where-Object {'/' -in $_.mountPointVec}
            if($volumeInfo){
                $Script:fsType = $volumeInfo.mountType
            } 
        }elseif($doc.objectId.entity.PSObject.Properties['genericNasEntity']){
            if($doc.objectId.entity.genericNasEntity.protocol -eq 2){
                $Script:fsType = 'SMB'
            }else{
                $Script:fsType = 'NFS'
            }
        }else{
            $Script:fsType = $jobType
        }
        listdir '/' $instance
    }
}

$jobs = api get protectionJobs
$policies = api get protectionPolicies

$searchResults = api get "/searchvms?entityTypes=kFlashBlade&entityTypes=kGenericNas&entityTypes=kIsilon&entityTypes=kNetapp&entityTypes=kPhysical&entityTypes=kVMware&vmName=*"

$x = 0
foreach($searchResult in $searchResults.vms | Sort-Object -Property {$_.vmDocument.jobName}, {$_.vmDocument.objectName}){
    $Global:firstEntry = $True
    $Global:trColor = $trColors[$x % 2]
    $x += 1
    $doc = $searchResult.vmDocument
    $objectName = $doc.objectName
    $jobName = $doc.jobName
    $jobType = $environments[$doc.backupType]
    $job = $jobs | Where-Object name -eq $jobName
    $policyName = '-'
    $policy = $policies | Where-Object id -eq $job.policyId
    if($policy){
        $policyName = $policy.name
    }
    $doc.versions = $doc.versions | Where-Object {$_.instanceId.jobStartTimeUsecs -lt $(timeAgo $daysAgo days)}
    if($doc.versions.Count -gt 0){
        $runId = $doc.versions[0].instanceId.jobInstanceId
        $lastBackup = (usecsToDate $doc.versions[0].instanceId.jobStartTimeUsecs).ToString('yyyy-MM-dd hh:mm')
        if($doc.backupType -le 22){
            $version = $doc.versions[0]
            showFiles $doc $version
        }
    }
}

$Global:html += "</table>                
</div>
</body>
</html>"

$Global:html | Out-File -FilePath $Global:htmlFileName

Write-Host "`nsaving report as $Global:htmlFileName"
Write-Host "also as csv file $csvFileName"

# send email
if($smtpServer -and $sendTo -and $sendFrom){
    Write-Host "`nsending report to $([string]::Join(", ", $sendTo))`n"
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject $title -BodyAsHtml $Global:html -WarningAction SilentlyContinue
    }
}
