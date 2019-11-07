# usage: .\linkShares.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName myjob -remoteComputer fileserver.mydomain.net -proxyComputer protectedcomputer.mydomain.net -localDirectory c:\Cohesity

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$remoteComputer,  # optional name of one server protect
    [Parameter(Mandatory = $True)][string]$proxyComputer,  # optional name of one server protect
    [Parameter(Mandatory = $True)][string]$localDirectory,  # optional textfile of servers to protect
    [Parameter(Mandatory = $True)][string]$jobName  # name of the job to add server to
)

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

$source = $sources.nodes | Where-Object {$_.protectionSource.name -eq $proxyComputer}
if(!$source){
    write-warning "Proxy Computer $proxyComputer not registered in Cohesity!"
    exit
}

# create any missing links
write-host "Searching for new links to create..."
$localLinks = (Get-Item $localDirectory) | Get-ChildItem
$remoteShares = Invoke-Command -ComputerName $remoteComputer -ScriptBlock { get-smbshare -Special $false }

$newLinksFound = $false
foreach($share in $remoteShares){
    $shareName = $share.name
    if($shareName -notin $localLinks.name){
        write-host "Creating new link $localDirectory\$shareName -> \\$remoteComputer\$shareName..."
        $null = new-item -ItemType SymbolicLink -Path $localDirectory -name $shareName -Value \\$remoteComputer\$shareName
        $newLinksFound = $True
    }
}

if($newLinksFound){
    # refresh localLinks
    $localLinks = (Get-Item $localDirectory) | Get-ChildItem

    # add new links to inclusions
    foreach($sourceSpecialParameter in $job.sourceSpecialParameters){
        if($sourceSpecialParameter.sourceId = $source.protectionSource.id){
            foreach($localLink in $localLinks){
                $linkPath = '/' + $localLink.fullName.replace(':','').replace('\','/')
                if($linkPath -notin $sourceSpecialParameter.physicalSpecialParameters.filePaths.backupFilePath){
                    write-host "adding new link $($localLink.fullName) to protection job..."
                    $sourceSpecialParameter.physicalSpecialParameters.filePaths += @{'backupFilePath' = $linkPath; 'skipNestedVolumes' = $false }
                }
            }
            $sourceSpecialParameter.physicalSpecialParameters.filePaths = $sourceSpecialParameter.physicalSpecialParameters.filePaths | Sort-Object -Property {$_.backupFilePath}
        }
    }

    # update job
    $null = api put "protectionJobs/$($job.id)" $job
}else{
    Write-Host "No new links found"
}
