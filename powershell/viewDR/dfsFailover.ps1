### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$nameSpace,
    [Parameter(Mandatory = $True)][string]$shareList,
    [Parameter(Mandatory = $True)][string]$disableTarget,
    [Parameter(Mandatory = $True)][string]$enableTarget
)

# gather share list
if(Test-Path -Path $shareList){
    $shares = Get-Content $shareList
}else{
    Write-Host "Can't find share list $shareList" -ForegroundColor Yellow
    exit 1
}

foreach($share in $shares){
    $shareName = [string]$share
    "Updating DFS folder target $shareName"
    $folderPath = Join-Path -Path $nameSpace -ChildPath $shareName
    $disableTargetPath = Join-Path -Path $disableTarget -ChildPath $shareName
    $enableTargetPath = Join-Path -Path $enableTarget -ChildPath $shareName
    $disableTargetPath
    $null = Set-DfsnFolderTarget -Path $folderPath -TargetPath $disableTargetPath -State Offline
    $null = Set-DfsnFolderTarget -Path $folderPath -TargetPath $enableTargetPath -State Online
}

