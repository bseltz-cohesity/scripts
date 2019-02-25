### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, #Cohesity username
    [Parameter()][string]$domain = 'local', #Cohesity user domain name
    [Parameter(Mandatory = $True)][string]$jobName #Name of the job to pause
)

$job = api get protectionJobs | Where-Object { $_.name -ieq $jobName }
if($job){
    $pauseTask = @{"pause" = $true}
    $pause = api post protectionJobState/$($job.id) $pauseTask 
}else{
    Write-Warning "Job $jobName not found..."
    exit
}