# usage: .\lastBackupAttribute.ps1 -vip mycluster -username myusername -domain mydomain.net -viServer vcenter.mydomain.net -viUser 'administrator@vsphere.local'

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$viServer,
    [Parameter(Mandatory = $True)][string]$viUser,
    [Parameter()][string]$viPassword = '',
    [Parameter()][string]$attributeName = 'Last Cohesity Backup'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate to Cohesity
apiauth -vip $vip -username $username -domain $domain

# authenticate to vSphere
if($viPassword -eq ''){
    $viPassword = Get-CohesityAPIPassword -vip $viServer -username $viUser
    if($viPassword -eq ''){
        Write-Host "Need Password for vCenter"
        $viPassword = Set-CohesityAPIPassword -vip $viServer -username $viUser
    }
}

$null = Connect-VIServer -Server $viServer -User $viUser -Password $viPassword -Force

# create custom attribute
if(! (Get-CustomAttribute | Where-Object Name -eq $attributeName)){
    New-CustomAttribute -Name $attributeName -TargetType VirtualMachine
}

# get latest backup jobs
$jobSummary = api get '/backupjobssummary?_includeTenantInfo=true&allUnderHierarchy=true&includeJobsWithoutRun=false&isActive=true&isDeleted=false&numRuns=1000&onlyReturnBasicSummary=true&onlyReturnJobDescription=false'

foreach($job in $jobSummary | Sort-Object -Property { $_.backupJobSummary.jobDescription.name }){
    # filter on VM job type and this vCenter
    if($job.backupJobSummary.jobDescription.type -eq 1 -and $job.backupJobSummary.jobDescription.parentSource.vmwareEntity.name -eq $viServer){
        $startTimeUsecs = $job.backupJobSummary.lastProtectionRun.backupRun.base.startTimeUsecs
        $jobId = $job.backupJobSummary.lastProtectionRun.backupRun.base.jobId
        if($jobId -and $startTimeUsecs){
            # latest job run
            $lastrun = api get "/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=$startTimeUsecs&id=$jobId&onlyReturnDataMigrationJobs=false"
            foreach($task in $lastrun.backupJobRuns.protectionRuns[0].backupRun.latestFinishedTasks){
                $status = $task.base.publicStatus
                $entity = $task.base.sources[0].source.displayName
                $entityStartTimeUsecs = $task.base.startTimeUsecs
                $entityStartTime = (usecsToDate $entityStartTimeUsecs).ToString("yyyy-MM-dd HH:mm:ss")
                write-host "$entityStartTime ($status) $entity"
                if($status -eq 'kSuccess' -or $status -eq 'kWarning'){
                    # annotate VM
                    $vm = Get-VM -Name $entity
                    if($vm){
                        $null = $vm | Set-Annotation -CustomAttribute $attributeName -Value $entityStartTime
                    }
                }
            }
        }
    }
}
