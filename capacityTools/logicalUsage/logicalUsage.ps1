### usage: ./logicalUsage.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] [ -days 90 ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][int]$days = 90
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$report = @{}

"Inspecting snapshots..."
foreach ($job in (api get protectionJobs)) {
    $runs = api get protectionRuns?jobId=$($job.id)`&numRuns=99999`&excludeNonRestoreableRuns=true`&runTypes=kFull`&runTypes=kRegular`&startTimeUsecs=$(timeAgo $days days)
    foreach ($run in $runs){
        if ($run.backupRun.snapshotsDeleted -eq $false) {
            foreach($source in $run.backupRun.sourceBackupStatus){
                $sourcename = $source.source.name
                if($sourcename -notin $report.Keys){
                    $report[$sourcename] = @{}
                    $report[$sourcename]['size'] = 0
                    $report[$sourcename]['environment'] = $source.source.environment
                }
                if($source.stats.totalLogicalBackupSizeBytes -gt $report[$sourcename]['size']){
                    $report[$sourcename]['size'] = $source.stats.totalLogicalBackupSizeBytes
                }
            }
        }
    }
}                                                                                           

"Inspecting Views..."
$views = api get views?includeInactive=true
foreach($view in $views.views){
    $viewname = $view.name
    if($view.name -notin $report.Keys){
        $report[$viewname] = @{}
        $report[$viewname]['size'] = $view.logicalUsageBytes
        $report[$viewname]['environment'] = 'kView'
    }
}

$total = 0

"`n{0,15}  {1,10:n0}  {2}" -f ('Environment', 'Size (GB)', 'Name')
"{0,15}  {1,10:n0}  {2}" -f ('===========', '=========', '====')
$report.GetEnumerator() | Sort-Object -Property {$_.Value.size} -Descending | ForEach-Object {
    "{0,15}  {1,10:n0}  {2}" -f ($_.Value.environment, ($_.Value.size/(1024*1024*1024)), $_.Name)
    $total += $_.Value.size
}
"`n    Total Logical Size: {0:n0} GB`n" -f ($total/(1024*1024*1024))
