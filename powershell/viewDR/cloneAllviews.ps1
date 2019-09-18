### usage: ./viewDRclone.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -inPath \\myserver\mypath\

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$inPath
)

if(test-path $inPath){
    $files = Get-ChildItem $inPath
}else{
    Write-Warning "Can't access $inPath"
    exit
}

foreach($file in $files){
    ./viewDRclone.ps1 -vip $vip -username $username -viewName $file.name -inPath $file.FullName
}