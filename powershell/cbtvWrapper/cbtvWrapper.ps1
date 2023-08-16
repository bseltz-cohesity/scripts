# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][string]$jobString
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -password $password -useApiKey
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

$jobs = api get protectionJobs | Where-Object {$_.name -match $jobString -and $_.isDeleted -ne $true -and $_.isActive -ne $false -and $_.environment -eq 'kSQL'}

foreach($job in $jobs){
    if($useApiKey){
        .\cloneBackupToView.ps1 -vip $vip -username $username -domain $domain -password $password -useApiKey -jobName "$($job.name)" -viewName "$(($job.name).replace(' ','-'))" -dbFolders -daysToKeep 3
    }else{
        .\cloneBackupToView.ps1 -vip $vip -username $username -domain $domain -password $password -jobName "$($job.name)" -viewName "$(($job.name).replace(' ','-'))" -dbFolders -daysToKeep 3
    }
}
