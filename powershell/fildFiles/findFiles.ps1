### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$extension
)

# source the cohesity-api helper code
. ./cohesity-api

# authenticate
apiauth -vip $vip -username $username -domain $domain

$results = api get "/searchfiles?filename=$($extension)"
write-host "`nFound $($results.files.count) results"

if($results.files.count -gt 0){
    $output = $results.files | where-object { $_.fileDocument.isDirectory -ne $True -and $_.fileDocument.filename -match $extension+'$'} |
                 Sort-Object -Property {$_.fileDocument.objectId.entity.displayName}, {$_.fileDocument.filename} |
                 Select-Object -Property @{Label='Server';Expression={$_.fileDocument.objectId.entity.displayName}}, @{Label='Path';Expression={$_.fileDocument.filename}}
    $output
    $output | Out-File -FilePath foundFiles.txt

    "`nsaving results to foundFiles.txt"
}

