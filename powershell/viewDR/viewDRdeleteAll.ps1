### usage: ./viewDRdeleteAll.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -inPath \\myserver\mypath

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

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$confirmed = $false

foreach($file in $files){
    $viewname = $file.name
    $filename = $file.FullName
    $metadata = Get-Content $fileName | ConvertFrom-Json
    $view = api get "views/$viewname"
    if($view){
        if($view.viewId -eq $metadata.viewId){
            if($confirmed -eq $false){
                write-host "**********************************************************" -ForegroundColor Red
                write-host "*** Warning: you are about to delete PRODUCTION views! ***" -ForegroundColor Red
                write-host "**********************************************************" -ForegroundColor Red
            }
        }else{
            if($confirmed -eq $false){
                write-host "You are about to delete DR views" -ForegroundColor Yellow
            }
        }
        if($confirmed -eq $false){
            $confirm = Read-Host -Prompt "Are you sure? Yes(No)"
            if($confirm.ToLower() -eq 'yes'){
                $confirmed = $True
            }else{
                "Cancelling..."
                exit
            }
        }
        if($confirmed -eq $True){
            "Deleting $viewname"
            # $null = api delete "views/$viewname"
        }
    }else{
        "View $viewname not found"
    }
}
