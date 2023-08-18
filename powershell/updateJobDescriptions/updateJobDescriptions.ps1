### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null,
    [Parameter(Mandatory=$True)][string]$csvFile,
    [Parameter()][switch]$export
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true"

if($export){
    Write-Host "Exporting protection groups name, description to $csvFile"
    $jobs.protectionGroups | Select-Object -Property name, description | Export-Csv -Path $csvFile
    exit
}

$csv = Import-Csv -Path $csvFile
if(!$csv){
    Write-Host "csv $csvFile file not found" -ForegroundColor Yellow
    exit
}

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    $csvItem = $csv | Where-Object name -eq $job.name
    if(! $csvItem){
        Write-Host "$($job.name) - no entry in CSV" -ForegroundColor Yellow
    }else{
        Write-Host "$($job.name) - updating description"
        $job.description = $csvItem.description
        $null = api put -v2 data-protect/protection-groups/$($job.id) $job
    }
}



