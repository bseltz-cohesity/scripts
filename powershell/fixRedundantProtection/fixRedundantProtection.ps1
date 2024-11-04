# usage: ./fixRedundantProtection.ps1 -vip myCluster -username myUser -jobName 'My Job' -fix

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][switch]$fix
)

# source the cohesity-api helper code
. ./cohesity-api

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get protectionJobs
$jobs = api get protectionJobs?isDeleted=false

# get specified job
$myJob = $jobs | Where-Object { $_.name -eq $jobName }
if(!$myJob){
    Write-Warning "Job $jobName not found!"
    exit
}

$redundanciesFound = $false
foreach ($job in @($jobs | Where-Object { $_.id -ne $myJob.id})){
    # find resundant source IDs
    $redundantSourceIds = $job.sourceIds | Where-Object { $_ -in $myJob.sourceIds }
    if($redundantSourceIds){
        $redundanciesFound = $True
        "Found The following objects also protected in job: $($job.name):"
        # Display name of redundant source
        foreach ($sourceId in $redundantSourceIds){
            $source = api get "protectionSources/objects/$sourceId"
            "  $($source.name)"
        }
        if($fix){
            "  fixing..."
            # Remove redundant sources from the other job
            $job.sourceIds = @($job.sourceIds | Where-Object { $_ -notin $myJob.sourceIds })
            if($job.PSObject.Properties['sourceSpecialParameters']){
                $job.sourceSpecialParameters = @($job.sourceSpecialParameters | Where-Object { $_.sourceId -notin $myJob.sourceIds })
            }
            if($job.sourceIds.length -eq 0){
                Write-Warning "Can't remove $($source.name) from $($job.name) because it would leave the job empty. Please just delete the job."
            }else{
                $null = api put "protectionJobs/$($job.id)" $job
            }
        }
    }
}

if(!$redundanciesFound){
    "No redundancies found"
}


