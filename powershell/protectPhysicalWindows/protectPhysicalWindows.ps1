# usage: ./protectPhysicalWindows.ps1 -vip mycluster -username myusername -jobName 'My Job' -serverList ./servers.txt -exclusionList ./exclusions.txt

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][string]$server = '',  # optional name of one server protect
    [Parameter()][string]$serverList = '',  # optional textfile of servers to protect
    [Parameter()][string]$exclusionList = './exclusions.txt',  # required list of exclusions
    [Parameter(Mandatory = $True)][string]$jobName  # name of the job to add server to
)

# gather list of servers to add to job
$serversToAdd = @()
if ('' -ne $server){
    $serversToAdd += $server
}
if ('' -ne $serverList){
    if(Test-Path -Path $serverList -PathType Leaf){
        $serversToAdd = Get-Content $serverList
    }
}

# gather exclusion list
if(Test-Path -Path $exclusionList -PathType Leaf){
    $exclusions = Get-Content $exclusionList
}else{
    Write-Warning "Exclusions file $exclusionList not found!"
    exit
}

# source the cohesity-api helper code
. ./cohesity-api

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get the protectionJob
$job = api get protectionJobs | Where-Object {$_.name -ieq $jobName}
if(!$job){
    Write-Warning "Job $jobName not found!"
    exit
}

# get physical protection sources
$sources = api get protectionSources?environment=kPhysical

# add sourceIds for new servers
$sourceIds = @($job.sourceIds)

foreach($server in $serversToAdd){
    $node = $sources.nodes | Where-Object { $_.protectionSource.name -eq $server }
    if($node){
        if($node.protectionSource.physicalProtectionSource.hostType -eq 'kWindows'){
            $sourceId = $node.protectionSource.id
            $sourceIds += $sourceId
        }else{
            Write-Warning "$server is not a Windows host"
        }
    }else{
        Write-Warning "$server is not a registered source"
    }
}

$sourceIds = @($sourceIds | Select-Object -Unique)

# process inclusions and exclusions
"Processing servers..."
$sourceSpecialParameters = @()

foreach($sourceId in $sourceIds){
    $sourceSpecialParameter = @{
        "sourceId" = $sourceId;
        "physicalSpecialParameters" = @{
            "filePaths" = @()
        }
    }
    $source = $sources.nodes | Where-Object {$_.protectionSource.id -eq $sourceId}
    "  $($source.protectionSource.name)"

    # identify existing source volumes
    $mountPoints = $source.protectionSource.physicalProtectionSource.volumes.mountPoints

    foreach ($mountPoint in $mountPoints | Where-Object {$_ -ne $null}) {

        $backupFilePath = "/$mountPoint".Replace(':\','/')

        $filePath = @{
            "backupFilePath" = $backupFilePath;
            "skipNestedVolumes" = $true;
            "excludedFilePaths" = @()
        }


        # identify exclusions that apply to existing source volumes
        $excludedFilePaths = @()
        foreach ($exclusion in $exclusions) {
            $exclusion = $exclusion.ToString()
            if ($exclusion.substring(0, 3) -eq $mountPoint) {
                $exclusion = "/$($exclusion.replace(':','').replace('\','/'))"
                $excludedFilePaths += $exclusion
            }
        }
        if($excludedFilePaths.Length -gt 0){
            
            $filePath.excludedFilePaths = @($filePath.excludedFilePaths + $excludedFilePaths | Select-Object -Unique)

        }
        if($mountPoint -notin $exclusions){
            $sourceSpecialParameter.physicalSpecialParameters.filePaths += $filePath
        }
    }
    $sourceSpecialParameters += $sourceSpecialParameter
}

# update job
$job.sourceSpecialParameters = $sourceSpecialParameters
$job.sourceIds = @($sourceIds)
$null = api put "protectionJobs/$($job.id)" $job
