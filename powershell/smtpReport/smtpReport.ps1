### usage: ./smtpreport.ps1 -vip mycluster -username myusername -domain mydomain.net -prefix demo,test -sendTo myuser@mydomain.net, anotheruser@mydomain.net -smtpServer 192.168.1.95 -sendFrom backupreport@mydomain.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][array]$prefix = 'all', #report jobs with 'prefix' only
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
$runs = @{}

### get report
$report = api get 'reports/protectionSourcesJobsSummary?allUnderHierarchy=true'

function tdhead($data, $color){
    '<td colspan="1" bgcolor="#' + $color + '" valign="top" align="CENTER" border="0"><font size="2">' + $data + '</font></td>'
}
function td($data, $color, $wrap='', $align='LEFT'){
    '<td ' + $wrap + ' colspan="1" bgcolor="#' + $color + '" valign="top" align="' + $align + '" border="0"><font size="2">' + $data + '</font></td>'
}

$html = '<html><table align="center" border="1" cellpadding="4" cellspacing="0" style="font-family: Roboto,RobotoDraft,Helvetica,Arial,sans-serif;font-size: small;">
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

foreach($source in $report.protectionSourcesJobsSummary){
    $html += '<tr>'
    $type = $source.protectionSource.environment.Substring(1)
    $name = $source.protectionSource.name
    $parentName = $source.registeredSource
    $jobName = $source.jobName
    $job = ($jobs | Where-Object {$_.name -eq $jobName})
    if($job){
        $jobId = $job[0].id
    }else{
        $jobId = $null
    }
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
        if ($jobName.tolower().startswith($pre.tolower()) -or $prefix -eq 'all') {
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
        if(([datetime]$lastRunStartTime) -lt (get-date).AddHours(-25)){
            $color = 'CC9999'
        }
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
    }
}

$html += '</tbody></table></html>'

write-host "sending report to $([string]::Join(", ", $sendTo))"
### send email report
foreach($toaddr in $sendTo){
    Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject "backupSummaryReport" -BodyAsHtml $html
}
