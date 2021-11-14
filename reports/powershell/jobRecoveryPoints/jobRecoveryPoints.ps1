[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$jobName,
    [Parameter()][string]$domain = 'local'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster
$todayUsecs = dateToUsecs (get-date)
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "RecoverPoints-$($cluster.name)-$dateString.csv"
"Job Name,Job Type,Backup Date,Local Expiry,Archival Target,Archival Expiry" | Out-File -FilePath $outfileName

$jobs = api get protectionJobs
if($jobName){
    $jobs = $jobs | Where-Object name -eq $jobName
}

foreach($job in $jobs | Sort-Object -Property name | Where-Object {$_.isDeleted -ne $True}){
    $jobName = $job.name
    $jobType = $job.environment.subString(1)
    write-host ("`n{0} ({1})" -f $jobName, $jobType) -ForegroundColor Green
    write-host "`n`t             RunDate           SnapExpires        ArchiveExpires" -ForegroundColor Blue
    $ro = api get "/searchvms?jobIds=$($job.id)"
    $jobRuns = $ro.vms.vmDocument.versions | Group-Object -Property {$_.instanceId.jobStartTimeUsecs}
    foreach($jobDate in $jobRuns | Sort-Object -Property Name -Descending){
        $jobRun = $jobDate.Group[0]
        $runDate = usecsToDate $jobDate.Name
        $replicas = $jobRun.replicaInfo.replicaVec
        $local = '-'
        $archive = '-'
        $archiveTarget = ''

        $replicas | ForEach-Object {
            if($_.target.type -eq 1){
                if($_.expiryTimeUsecs -gt $todayUsecs){
                    $local = usecsToDate $_.expiryTimeUsecs
                }
            }elseif($_.target.type -eq 3) {
                $archiveTarget = $_.target.archivalTarget.name
                if($_.expiryTimeUsecs -gt $todayUsecs){
                    $archive = usecsToDate $_.expiryTimeUsecs
                }
            }
        }

        "`t{0,20}  {1,20}  {2,20}" -f $runDate, $local, $archive
            
        "$jobName,$jobType,$runDate,$local,$archiveTarget,$archive" | Out-File -FilePath $outfileName -Append
    }
}
