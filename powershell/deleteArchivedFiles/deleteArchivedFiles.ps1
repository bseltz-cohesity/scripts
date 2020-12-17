### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, # Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, # Cohesity username
    [Parameter()][string]$domain = 'local', # Cohesity user domain name
    [Parameter(Mandatory = $True)][string]$jobName # Name of the protection job
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

# find the job
$job = api get protectionJobs?environments=kView | Where-Object {$_.name -eq $jobName}
if(!$job){
    Write-Host "Job $jobName not found!" -ForegroundColor Yellow
    exit 1
}

# find the view
$view = ((api get views).views | Where-Object {$_.viewProtection.protectionJobs.jobId -eq $job.id})[0]
if(!$view){
    Write-Host "Couldn't find view" -ForegroundColor Yellow
    exit 1
}

# directory walker

function processFolder($thisFolder, $latestRunDate, $deleteMe){
    $lastAccessTime = $thisFolder.lastWriteTime
    write-host ("{0}" -f $thisFolder.FullName)
    $children = get-childItem -Path $thisFolder.FullName -Force
    $remainingChildren = $false
    if($children){
        foreach($child in $children){
            if($child.PSIsContainer){
                $thisRemaining = processFolder $child $latestRunDate $true
                if($thisRemaining){
                    $remainingChildren = $true
                }
            }else{
                $createTime = $child.creationTime
                $writeTime = $child.lastWriteTime
                # remove old file
                if($lastAccessTime -ge $latestRunDate -or 
                   $createTime -ge $latestRunDate -or
                   $writeTime -ge $latestRunDate){
                   $remainingChildren = $true
                }
            }
        }
    }
    if($false -eq $remainingChildren -and $true -eq $deleteMe){
        $thisFolder | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }else{
        return $true
    }
}

# find latest archival date
$runs = api get "protectionRuns?jobId=$($job.id)&excludeTasks=true&numRuns=999" | Where-Object {$_.backupRun.status -eq 'kSuccess'}
       
if($runs){
    $copyRuns = $runs.copyRun | Where-Object {$_.target.type -eq 'kArchival' -and $_.status -eq 'kSuccess'}
    if($copyRuns){
        $latestRunDate = usecsToDate ($copyRuns[0].runStartTimeUsecs)
        write-host "Latest completed archive run was $latestRunDate"
        "Looking for files written before that date..."
        $mountPath = $view.smbMountPath
        $null = processFolder (get-item -path $mountPath) $latestRunDate $false
    }else{
        Write-Host "No completed archive runs yet" -ForegroundColor Yellow
    }
}else{
    Write-Host "No completed protection runs yet" -ForegroundColor Yellow
}
