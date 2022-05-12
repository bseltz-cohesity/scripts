# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][int]$numRuns = 1000
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "datalockSnapshots-$($cluster.name)-$dateString.csv"

# headings
"Job Name, Run Date" | Out-File -FilePath $outfileName

foreach($job in $jobs | Sort-Object -Property name){
    $endUsecs = dateToUsecs (Get-Date)
    "{0}" -f $job.name
    while($True){
        $runs = api get "protectionRuns?jobId=$($job.id)&numRuns=$numRuns&endTimeUsecs=$endUsecs&excludeTasks=true"
        if($runs.Count -gt 0){
            $endUsecs = $runs[-1].backupRun.stats.startTimeUsecs - 1
        }else{
            break
        }
        foreach($run in $runs){
            $runStartTime = usecsToDate $run.backupRun.stats.startTimeUsecs
            if($run.backupRun.snapshotsDeleted -eq $False -and $run.backupRun.PSObject.Properties['wormRetentionType'] -and $run.backupRun.wormRetentionType -eq 'kCompliance'){
                "    {0}" -f $runStartTime
                """{0}"",""{1}""" -f $job.name, $runStartTime | Out-File -FilePath $outfileName -Append 
            }
        }
    }
}

"`nOutput saved to $outfilename`n"
