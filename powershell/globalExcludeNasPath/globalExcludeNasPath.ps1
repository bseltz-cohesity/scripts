[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$excludePath,
    [Parameter()][switch]$remove
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$jobs = api get protectionJobs?environments=kGenericNas

foreach($job in $jobs){
    "$($job.name)"
    $excludeFilters = $job.environmentParameters.nasParameters.filePathFilters.excludeFilters
    if($remove){
        $job.environmentParameters.nasParameters.filePathFilters.excludeFilters = @($excludeFilters | Where-Object {$_ -ne $excludePath})
    }else{
        $job.environmentParameters.nasParameters.filePathFilters.excludeFilters = @($excludeFilters + $excludePath)
    }
    $null = api put protectionJobs/$($job.id) $job
}
