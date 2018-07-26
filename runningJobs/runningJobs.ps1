### usage: ./runningJobs.ps1 -vip 192.168.1.198 -username admin [ -domain local ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local' #local or AD domain
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### protection runs
$runs = api get protectionRuns | sort-object -property @{Expression={$_.backupRun.stats.startTimeUsecs}} #| ?{ $_.copyRun.length -gt 1 }
$overallstatus = 'No Jobs Running'
foreach ($run in $runs){
    $stillRunning = $false
    $jobName = $run.jobName
    $runStartTime = $run.backupRun.stats.startTimeUsecs
    $startTime = usecsToDate $runStartTime
    if($run.backupRun.stats.endTimeUsecs -eq $null){
        $overallstatus = $null
        $stillRunning = $True
        $targetType = 'Local Snapshot'
        $status = $run.backupRun.status.substring(1)
        "{0,-20} {1,-20} {2,-15} {3}" -f ($jobName, $startTime, $targetType, $status)
    }else{
        foreach ($copyRun in $run.copyRun){
            if ($copyRun.target.type -ne 'kLocal'){
                if ($copyRun.stats.endTimeUsecs -eq $null){
                    $overallstatus = $null
                    $stillRunning = $True
                    $targetType = $copyRun.target.type.substring(1) 
                    $status = $copyRun.status.substring(1)
                    "{0,-20} {1,-20} {2,-15} {3}" -f ($jobName, $startTime, $targetType, $status)
                }
            }
        }
    }
}
$overallstatus
