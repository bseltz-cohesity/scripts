### usage: .\viewDRcollect.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -inPath \\myserver\mypath

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter(Mandatory = $True)][string]$outPath
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

### get views
$views = api get views
$jobs = api get protectionJobs

if(test-path $outPath){
    $clusterOutPath = Join-Path -Path $outPath -ChildPath $vip
    if(! (Test-Path -PathType Container -Path $clusterOutPath)){
        $null = New-Item -ItemType Directory -Path $clusterOutPath -Force
    }
    write-host "Saving view metadata to $clusterOutPath"
}else{
    Write-Warning "$outPath not accessible"
    exit
}

foreach($view in $views.views){
    $remoteViewName = $False
    if($view.PSObject.Properties['viewProtection']){
        $job = $jobs | Where-Object {$_.name -eq $view.viewProtection.protectionJobs[0].jobName}
        if($job.PSObject.Properties['remoteViewName']){
            $remoteViewName = $job.remoteViewName
        }
    }
    setApiProperty -object $view -name remoteViewName -value $remoteViewName
    $filePath = Join-Path -Path $clusterOutPath -ChildPath $view.name
    $view | ConvertTo-Json -Depth 99 | Out-File $filePath
}

