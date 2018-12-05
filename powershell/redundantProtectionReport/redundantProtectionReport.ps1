### usage: ./redundantProtectionReport.ps1 -vip 192.168.1.198 -username admin [ -domain local ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'
)

$outFile = $vip + '-redundantProtectionReport.csv'

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

"`nCollecting Report of Objects Protected by Multiple Jobs..."

### get protectionJobs
$jobs = api get protectionJobs?isDeleted=false

$sources = @{}

### get report
foreach ($job in $jobs){
    $report = api get reports/protectionSourcesJobsSummary?jobIds=$($job.id)
    foreach($summary in $report.protectionSourcesJobsSummary){
        if($summary.protectionSource.id -in $sources.Keys){
            $sources[$summary.protectionSource.id] += $job.name
        }else{
            $sources[$summary.protectionSource.id] = @($job.name)
        }
    }
}

$namedSources = @{}
$environments = @{}

### gather source names and types
foreach ($source in $sources.Keys){
    if ($sources[$source].Count -gt 1){
        $sourceObject = api get "protectionSources/objects/$source"
        $namedSources[$sourceObject.name] = $sources[$source]
        $environments[$sourceObject.name] = $sourceObject.environment.Substring(1)        
    }
}

### display output
"`nObject (Type) Jobs"
"------------------`n"
foreach ($source in ($namedSources.Keys | Sort-Object )){
    "$source ($($environments[$source]))"
    foreach ($jobName in ($namedSources[$source] | Sort-Object)){
        "`t" + $jobName
    }
}

### write out to CSV file
"Object,Type,Protection Jobs" | Out-File $outFile
foreach ($source in ($namedSources.Keys | Sort-Object )){
    "$source,$($environments[$source]),$(($namedSources[$source] | Sort-Object) -join ',')" | Out-File $outFile -Append
}

"`nOutput Saved to $outFile`n"

