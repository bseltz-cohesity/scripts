# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain name
    [Parameter()][array]$jobName,
    [Parameter()][string]$joblist,
    [Parameter()][switch]$commit
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster
$outFile = "log-unprotectMissingVMs-$($cluster.name).txt"
"`nStarted at $(get-date)`n" | Out-File -FilePath $outFile -Append

# gather job names
$jobsToUpdate = @()
foreach($job in $jobName){
    $jobsToUpdate += $job
}
if ('' -ne $jobList){
    if(Test-Path -Path $jobList -PathType Leaf){
        $jobs = Get-Content $jobList
        foreach($job in $jobs){
            $jobsToUpdate += [string]$job
        }
    }else{
        Write-Warning "job list $jobList not found!"
        exit
    }
}

"`nInspecting VMware Protection Jobs...`n"

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&environments=kVMware"

$missingVMsFound = $false

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    "  $($job.name)" | Tee-Object -FilePath $outFile -Append
    if($jobsToUpdate.Count -eq 0 -or $job.name -in $jobsToUpdate){
        if($job.missingEntities.Count -gt 0){      
            # backup job
            $job | ConvertTo-Json -Depth 99 | Out-File -FilePath "backup-of-$($job.name).json"
            foreach($missingEntity in $job.missingEntities | Sort-Object -Property name){
                $missingVMsFound = $True
                if($commit){
                    "    Removing: $($missingEntity.name)" | Tee-Object -FilePath $outFile -Append
                }else{
                    "    Missing: $($missingEntity.name)" | Tee-Object -FilePath $outFile -Append
                }
            }
            if($commit){
                $job.vmwareParams.objects = @($job.vmwareParams.objects | Where-Object id -notin $job.missingEntities.id)
                if($job.vmwareParams.objects.Count -gt 0){
                    $null = api put "data-protect/protection-groups/$($job.id)" $job -v2
                }else{
                    "    No objects left in $($job.name). Deleting..." | Tee-Object -FilePath $outFile -Append
                    $null = api delete "data-protect/protection-groups/$($job.id)" -v2
                }
            }
        }
    }
}

if($missingVMsFound){
    ""
}else{
    "`nNo missing VMs found`n"
}
