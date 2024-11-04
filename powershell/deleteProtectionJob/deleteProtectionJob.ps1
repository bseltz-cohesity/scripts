# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][switch]$deleteSnapshots
)

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $True)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

# outfile
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "log-deleteProtectionJob-$dateString.txt"

$jobs = api get -v2 "data-protect/protection-groups?includeTenants=true"

$notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
if($notfoundJobs){
    Write-Host "Jobs not found: $($notfoundJobs -join ', ')" -ForegroundColor Yellow
    exit 1
}

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    if($job.name -in $jobNames){
        if($deleteSnapshots){
            "DELETING JOB: $($job.name) (and deleting existing snapshots)" | Tee-Object -FilePath $outfileName -Append
            $null = api delete -v2 "data-protect/protection-groups/$($job.id)?deleteSnapshots=true"
        }else{
            "DELETING JOB: $($job.name) (but retaining existing snapshots)" | Tee-Object -FilePath $outfileName -Append
            $null = api delete -v2 "data-protect/protection-groups/$($job.id)?deleteSnapshots=false"
        }
    }
}

"`nOutput saved to $outfilename`n"
