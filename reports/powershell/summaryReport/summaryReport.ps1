### Usage: ./summaryReportXLSX.ps1 -vip mycluster -username myuser -domain mydomain.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$localOnly
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

"`nGathering report data..."

### get jobs
$jobs = api get protectionJobs

### get report
$report = api get 'reports/protectionSourcesJobsSummary?allUnderHierarchy=true'

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "summaryReport-$($cluster.name)-$dateString.csv"

# headings
"Type,Object,Source,Job Name,Snapshots,Last Status,Schedule Type,Last Start,End,First Success,First Failure,Last Success,Last Failure,Errors,Data Read,Logical Protected,Last Error Message" | Out-File -FilePath $outfileName

### populate data
$rownum = 2
foreach($source in $report.protectionSourcesJobsSummary){
    $type = $source.protectionSource.environment.Substring(1)
    $name = $source.protectionSource.name
    $parentName = $source.registeredSource
    $jobName = $source.jobName
    $job = $jobs | Where-Object {$_.name -eq $jobName}
    $jobId = $job.id
    $numSnapshots = $source.numSnapshots
    $lastRunStatus = $source.lastRunStatus.Substring(1)
    $lastRunType = $source.lastRunType.Substring(1)
    $lastRunStart = usecsToDate $source.lastRunStartTimeUsecs
    $lastRunEnd = usecsToDate $source.lastRunEndTimeUsecs
    $firstSuccessful = usecsToDate $source.firstSuccessfulRunTimeUsecs
    $lastSuccessful = usecsToDate $source.lastSuccessfulRunTimeUsecs
    if($lastRunStatus -eq 'Error'){
        $lastRunErrorMsg = $source.lastRunErrorMsg.replace("`r`n"," ").split('.')[0]
        $firstFailed = usecsToDate $source.firstFailedRunTimeUsecs
        $lastFailed = usecsToDate $source.lastFailedRunTimeUsecs
    }else{
        $lastRunErrorMsg = ''
        $firstFailed = ''
        $lastFailed = ''
    }
    $numDataReadBytes = $source.numDataReadBytes
    $numDataReadBytes = $numDataReadBytes/$numSnapshots
    if($numDataReadBytes -lt 1000){
        $numDataReadBytes = "$([math]::Round($numDataReadBytes, 2)) B"
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
        $numLogicalBytesProtected = "$([math]::Round($numLogicalBytesProtected, 2)) B"
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

    if((! $localOnly) -or ($job.isActive -ne $false)){

        """$type"",""$name"",""$parentName"",""$jobName"",""$numSnapshots"",""$lastRunStatus"",""$lastRunType"",""$lastRunStart"",""$lastRunEnd"",""$firstSuccessful"",""$firstFailed"",""$lastSuccessful"",""$lastFailed"",""$numErrors"",""$numDataReadBytes"",""$numLogicalBytesProtected"",""$lastRunErrorMsg""" | Out-File -FilePath $outfileName -Append
    }
}

"`nOutput saved to $outfilename`n"
