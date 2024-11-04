# usage: .\linkSharesProxy.ps1 -vip mycluster `
#                              -username myusername `
#                              -domain mydomain.net `
#                              -jobName 'my job name' `
#                              -nas mynas `
#                              -localDirectory C:\Cohesity\ `
#                              -statusFolder \\mylinkmaster\myshare

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$nas,  # name of nas target
    [Parameter(Mandatory = $True)][string]$localDirectory,  # local path where links will be created
    [Parameter(Mandatory = $True)][string]$statusFolder,  # unc path to central json file
    [Parameter(Mandatory = $True)][string]$jobName,  # name of cohesity protection job
    [Parameter()][switch]$register
)

$thisComputer = $Env:Computername
$logFile = Join-Path -Path $statusFolder -ChildPath "$thisComputer.log"
$statusFile = Join-Path -Path $statusFolder -ChildPath "linkSharesStatus.json"
$config = Get-Content -Path $statusFile | ConvertFrom-Json
"Check in at $(Get-Date)" | Out-File -FilePath $logFile

if($register){
    if(! ($config.proxies | Where-Object name -eq $thisComputer)){
        "registering as new proxy" | Tee-Object -FilePath $logFile -Append
        $config.proxies += @{'name'= $thisComputer; 'shows'= @()}
        $config | ConvertTo-Json -Depth 99 | Set-Content -Path $statusFile
    }
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get the protectionJob
$job = api get protectionJobs | Where-Object {$_.name -ieq $jobName}
if(!$job){
    "Job $jobName not found!" | Tee-Object -FilePath $logFile -Append
    exit 1
}

# get physical protection sources
$sources = api get protectionSources?environment=kPhysical

$source = $sources.nodes | Where-Object {$_.protectionSource.name -match $thisComputer}
if(!$source){
    "$thisComputer not registered in Cohesity!" | Tee-Object -FilePath $logFile -Append
    exit 1
}

$localLinks = (Get-Item $localDirectory) | Get-ChildItem

$thisProxy = $config.proxies | Where-Object name -eq $thisComputer

# report existing shows
foreach($localLink in $localLinks.Name){
    $showname = $localLink.split('_')[0]
    if(! ($showname -in $thisProxy.shows)){
        $thisProxy.shows += $showname
    }
}

# check for new links to create
$newLinksFound = $false
$myShows = $thisProxy.shows
$workSpaces = $config.workspaces
foreach($workspace in $workSpaces){
    $show = $workspace.split('_')[0]
    if($show -in $myShows){
        if(! ($workspace -in $localLinks.Name)){
            "adding $workspace" | Tee-Object -FilePath $logFile -Append
            $null = new-item -ItemType SymbolicLink -Path $localDirectory -name $workspace -Value \\$nas\$workspace
            $newLinksFound = $True
        }
    }
}

if($newLinksFound){
    # refresh localLinks
    $localLinks = (Get-Item $localDirectory) | Get-ChildItem

    # add new links to inclusions
    foreach($sourceSpecialParameter in $job.sourceSpecialParameters){
        if($sourceSpecialParameter.sourceId -eq $source.protectionSource.id){
            foreach($localLink in $localLinks){
                $linkPath = '/' + $localLink.fullName.replace(':','').replace('\','/')
                if($linkPath -notin $sourceSpecialParameter.physicalSpecialParameters.filePaths.backupFilePath){
                    "adding new link $($localLink.fullName) to protection job..." | Tee-Object -FilePath $logFile -Append
                    $sourceSpecialParameter.physicalSpecialParameters.filePaths += @{'backupFilePath' = $linkPath; 'skipNestedVolumes' = $false }
                }
            }
            $sourceSpecialParameter.physicalSpecialParameters.filePaths = $sourceSpecialParameter.physicalSpecialParameters.filePaths | Sort-Object -Property {$_.backupFilePath}
        }
    }

    # update job
    $null = api put "protectionJobs/$($job.id)" $job
}else{
    "No new links found" | Tee-Object -FilePath $logFile -Append
}
"Completed at $(get-date)" | Tee-Object -FilePath $logFile -Append
