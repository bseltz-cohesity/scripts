# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][string]$configFolder = './configExports'  # folder to store export files
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# create export folder
if(! (Test-Path -PathType Container -Path $configFolder)){
    $null = New-Item -ItemType Directory -Path $configFolder -Force
}

write-host "Exporting configuration information to $configFolder..."

api get protectionSources?environments=kAWS | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configFolder -ChildPath 'awsSources.json')
$jobs = api get -v2 data-protect/protection-groups?environments=kAWS
$jobs = $jobs.protectionGroups | Where-Object {$_.awsParams.protectionType -eq 'kSnapshotManager'}
$jobs | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $configFolder -ChildPath 'awsJobs.json')
