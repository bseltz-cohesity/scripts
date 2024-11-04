### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$extensionList
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# map job IDs to job Names
$jobs = api get protectionJobs?allUnderHierarchy=true
$jobName = @{}
$jobs | ForEach-Object {
    $jobName[$_.id] = $_.name
}

$extensions = Get-Content $extensionList | sort

$cluster = api get cluster
$dateString = get-date -UFormat '%Y-%m-%d'
$outfile = "foundFiles-$($cluster.name)-$dateString.csv"

foreach($extension in $extensions){
    $extension = [System.Web.HttpUtility]::UrlEncode($extension)
    $results = api get "/searchfiles?filename=$extension"
    $extension
    if($results.files.count -gt 0){
        $output = $results.files | where-object { $_.fileDocument.isDirectory -ne $True -and $_.fileDocument.filename -match $extension+'$' -and $_.fileDocument.filename.IndexOf($extension) + $extension.Length - $_.fileDocument.filename.Length -eq 0} |
                    Sort-Object -Property {$_.fileDocument.objectId.entity.displayName}, {$_.fileDocument.filename} |
                    Select-Object -Property @{Label='Protection Job';Expression={$jobName[$_.fileDocument.objectId.jobId]}}, @{Label='Server';Expression={$_.fileDocument.objectId.entity.displayName}}, @{Label='Path';Expression={$_.fileDocument.filename}}
        if($output){
            $output | Export-Csv -Path $outfile -Append
        }
    }
}
"`nsaving results to $outfile"
