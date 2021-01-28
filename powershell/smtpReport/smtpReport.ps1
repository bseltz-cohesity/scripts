### usage: ./smtpreport.ps1 -vip mycluster `
#                           -username myusername `
#                           -domain mydomain.net `
#                           -prefix demo,test 
#                           -sendTo myuser@mydomain.net, anotheruser@mydomain.net 
#                           -smtpServer 192.168.1.95 
#                           -sendFrom backupreport@mydomain.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][array]$prefix = 'ALL', #report jobs with 'prefix' only
    [Parameter(Mandatory = $True)][string]$smtpServer, #outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, #outbound smtp port
    [Parameter(Mandatory = $True)][array]$sendTo, #send to address
    [Parameter(Mandatory = $True)][string]$sendFrom #send from address
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

write-host "Gathering Job Stats..."
### get jobs
$jobs = api get protectionJobs
$policies = api get protectionPolicies
$runs = @{}
$cluster = api get cluster

function tdhead($data, $color){
    '<td colspan="1" bgcolor="#' + $color + '" valign="top" align="CENTER" border="0"><font size="2">' + $data + '</font></td>'
}
function td($data, $color, $wrap='', $align='LEFT'){
    '<td ' + $wrap + ' colspan="1" bgcolor="#' + $color + '" valign="top" align="' + $align + '" border="0"><font size="2">' + $data + '</font></td>'
}

$html = '<html>'

$prefixTitle = "($([string]::Join(", ", $prefix.ToUpper())))"

$html += '<div style="font-family: Roboto,RobotoDraft,Helvetica,Arial,sans-serif;font-size: small;"><font face="Tahoma" size="+3" color="#000080">
<center>Backup Job Summary Report<br>
<font size="+2">Backup Job Summary Report - ' + $prefixTitle + ' Daily Backup Report</font></center>
</font>
<hr>
Report generated on ' + (get-date) + '<br>
Cohesity Cluster: ' + $cluster.name + '<br>
Cohesity Version: ' + $cluster.clusterSoftwareVersion + '<br>
<br><br></div>'

$html += '<table align="center" border="1" cellpadding="4" cellspacing="0" style="font-family: Roboto,RobotoDraft,Helvetica,Arial,sans-serif;font-size: small;">
<tbody><tr><td colspan="21" align="CENTER" valign="TOP" bgcolor="#000080"><font size="+1" color="#FFFFFF">Summary</font></td></tr><tr bgcolor="#FFFFFF">'

$headings = @('Protection Object Type',
              'Protection Object Name', 
              'Registered Source Name',	
              'Protection Job Name', 
              'Num Snapshots',	
              'Last Run Status', 
              'Schedule Type',	
              'Last Run Start Time', 
              'End Time', 
              'First Successful Snapshot', 
              'First Failed Snapshot', 
              'Last Successful Snapshot', 
              'Last Failed Snapshot', 
              'Num Errors', 
              'Data Read',	
              'Logical Protected', 
              'Last Error Message')

foreach($heading in $headings){
    $html += td $heading 'CCCCCC' '' 'CENTER'
}
$html += '</tr>'
$nowrap = 'nowrap'

foreach($job in $jobs){
    # only local jobs
    if($job.uid.clusterId -eq $job.policyId.split(":")[0]){
        $policy = $policies | Where-Object id -eq $job.policyId
        # set lateHours based on policy frequency
        if($policy.incrementalSchedulingPolicy.dailySchedule.days){
            $lateHours = 169
        }else{
            $lateHours = 25
        }
        $report = api get "reports/protectionSourcesJobsSummary?allUnderHierarchy=true&jobIds=$($job.id)"
        foreach($source in ($report.protectionSourcesJobsSummary | Sort-Object -Property {$_.protectionSource.name})){
            $environment = $source.protectionSource.environment
            $type = $source.protectionSource.environment.Substring(1)
            $name = $source.protectionSource.name
            $sourceID = $source.protectionSource.id
            $parentID = $source.protectionSource.parentId
            if($parentID){
                $protectedSource = api get "protectionSources/protectedObjects?environment=$environment&id=$parentID"
            }else{
                $protectedSource = api get "protectionSources/protectedObjects?environment=$environment&id=$sourceID"
            }
            # $protectedSource | ConvertTo-Json -Depth 99
            $parentName = $source.registeredSource
            "$name $parentName"
            # $source | ConvertTo-Json
            $jobName = $job.name
            $jobId = $job.id
            $jobUrl = "https://$vip/protection/job/$jobId/details"
            $numSnapshots = $source.numSnapshots
            $lastRunStatus = $source.lastRunStatus.Substring(1)
            $lastRunType = $source.lastRunType
            $lastRunStartTime = usecsToDate $source.lastRunStartTimeUsecs
            $lastRunEndTime = usecsToDate $source.lastRunEndTimeUsecs
            $firstSuccessfulRunTime = usecsToDate $source.firstSuccessfulRunTimeUsecs
            $lastSuccessfulRunTime = usecsToDate $source.lastSuccessfulRunTimeUsecs
            if($lastRunStatus -eq 'Error'){
                $lastRunErrorMsg = $source.lastRunErrorMsg.replace("`r`n"," ").split('.')[0]
                $firstFailedRunTime = usecsToDate $source.firstFailedRunTimeUsecs
                $lastFailedRunTime = usecsToDate $source.lastFailedRunTimeUsecs
            }else{
                $lastRunErrorMsg = ''
                $firstFailedRunTime = ''
                $lastFailedRunTime = ''
            }
            $numDataReadBytes = $source.numDataReadBytes
            $numDataReadBytes = $numDataReadBytes/$numSnapshots
            if($numDataReadBytes -lt 1000){
                $numDataReadBytes = "$numDataReadBytes B"
            }elseif ($numDataReadBytes -lt 1000000) {
                $numDataReadBytes = "$([math]::Round($numDataReadBytes/1024, 2)) KiB"
            }elseif ($numDataReadBytes -lt 1000000000) {
                $numDataReadBytes = "$([math]::Round($numDataReadBytes/(1024*1024), 2)) MiB"
            }elseif ($numDataReadBytes -lt 1000000000000) {
                $numDataReadBytes = "$([math]::Round($numDataReadBytes/(1024*1024*1024), 2)) GiB"
            }else{
                $numDataReadBytes = "$([math]::Round($numDataReadBytes/(1024*1024*1024*1024), 2)) TiB"
            }
            $numLogicalBytesProtected = $source.numLogicalBytesProtected/$numSnapshots
            if($numLogicalBytesProtected -lt 1000){
                $numLogicalBytesProtected = "$numLogicalBytesProtected B"
            }elseif ($numLogicalBytesProtected -lt 1000000) {
                $numLogicalBytesProtected = "$([math]::Round($numLogicalBytesProtected/1024, 2)) KiB"
            }elseif ($numLogicalBytesProtected -lt 1000000000) {
                $numLogicalBytesProtected = "$([math]::Round($numLogicalBytesProtected/(1024*1024), 2)) MiB"
            }elseif ($numLogicalBytesProtected -lt 1000000000000) {
                $numLogicalBytesProtected = "$([math]::Round($numLogicalBytesProtected/(1024*1024*1024), 2)) GiB"
            }else{
                $numLogicalBytesProtected = "$([math]::Round($numLogicalBytesProtected/(1024*1024*1024*1024), 2)) TiB"
            }

            $numErrors = $source.numErrors + $source.numWarnings

            $sendjob = $false
            foreach($pre in $prefix){
                if ($jobName.tolower().startswith($pre.tolower()) -or $prefix -eq 'ALL') {
                    $sendjob = $true
                }
            }
            if ($sendjob) {
                if($lastRunStatus -eq 'Warning'){
                    $color = '00FFCC'
                }
                if($lastRunStatus -eq 'Error'){
                    $color='FF3366'
                }
                if($lastRunStatus -eq 'Success'){
                    $color='CCFFCC'
                }
                if($jobId){
                    if($runs.ContainsKey($jobId)){
                        $run = $runs[$jobId]
                    }else{
                        $run = api get "protectionRuns?jobId=$jobId&numRuns=1"
                        $runs[$jobId] = $run
                    }
                    if($run.backupRun.status -eq 'kAccepted'){
                        $color='66ABDD'
                    }
                    if($run.backupRun.status -eq 'kCanceled'){
                        $color='FF99CC'
                    }
                }
                if(([datetime]$lastRunStartTime) -lt (get-date).AddHours(-$lateHours)){
                    $color = 'CC9999'
                }
                $html += '<tr>'
                $html += td $type $color $nowrap
                $html += td $name $color $nowrap
                $html += td $parentName $color $nowrap
                $html += td "<a href=$jobUrl>$jobName</a>" $color $nowrap
                $html += td $numSnapshots $color $nowrap 'CENTER'
                $html += td $lastRunStatus $color $nowrap
                $html += td $lastRunType $color $nowrap
                $html += td $lastRunStartTime $color '' 'CENTER'
                $html += td $lastRunEndTime $color '' 'CENTER'
                $html += td $firstSuccessfulRunTime $color '' 'CENTER'
                $html += td $firstFailedRunTime $color '' 'CENTER'
                $html += td $lastSuccessfulRunTime $color '' 'CENTER'
                $html += td $lastFailedRunTime $color '' 'CENTER'
                $html += td $numErrors $color $nowrap 'CENTER'
                $html += td $numDataReadBytes $color $nowrap
                $html += td $numLogicalBytesProtected $color $nowrap
                $html += td $lastRunErrorMsg $color $nowrap
                $html += '</tr>'
            }
        }
    }
}

$html += '</tbody></table><br><br><hr><li>Color based on job status:
<table align="center" border="1" cellpadding="4" cellspacing="0">
<tbody>
<tr>
<td bgcolor="#66ABDD" valign="top" align="center" border="0" width="100"><font size="1">Running</font></td>
<td bgcolor="#CC99FF" valign="top" align="center" border="0" width="100"><font size="1">Delayed</font></td>
<td bgcolor="#CCFFCC" valign="top" align="center" border="0" width="100"><font size="1">Completed</font></td>
<td bgcolor="#FFCC99" valign="top" align="center" border="0" width="100"><font size="1">Completed with errors</font></td>
<td bgcolor="#00FFCC" valign="top" align="center" border="0" width="100"><font size="1">Completed with warnings</font></td>
<td bgcolor="#FF99CC" valign="top" align="center" border="0" width="100"><font size="1">Cancelled</font></td>
<td bgcolor="#FF3366" valign="top" align="center" border="0" width="100"><font size="1">Failed</font></td>
</tr>
</tbody>
</table>
<table align="center" border="1" cellpadding="4" cellspacing="0">
<tbody>
<tr>
<td bgcolor="#CC9999" valign="top" align="center" border="0" width="100"><font size="1">Aged</font></td>
<td bgcolor="#FFFFFF" valign="top" align="center" border="0" width="100"><font size="1">No Schedule</font></td>
<td bgcolor="#FF9999" valign="top" align="center" border="0" width="100"><font size="1">No Run</font></td>
<td bgcolor="93C54B" valign="top" align="center" border="0" width="100"><font size="1">Committed</font></td>
<td bgcolor="#CCFFFF" valign="top" align="center" border="0" width="100"><font size="1">Increase/Decrease in Data Size by 10% or more</font></td>
</tr>
</tbody>
</table>
</li></html>'

write-host "sending report to $([string]::Join(", ", $sendTo))"
### send email report
foreach($toaddr in $sendTo){
    Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject "$prefixTitle backupSummaryReport" -BodyAsHtml $html -WarningAction SilentlyContinue
}
$html | out-file smtpreport.html