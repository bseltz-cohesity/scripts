### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$nameSpace,
    [Parameter()][string]$shareList,
    [Parameter()][string]$shareName,
    [Parameter(Mandatory = $True)][string]$disableTarget,
    [Parameter(Mandatory = $True)][string]$enableTarget
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

$shares = @(gatherList -Param $shareName -FilePath $shareList -Name 'shares' -Required $True)

$alltargets = @()
$nameSpaceFolders = Get-DfsnFolder -Path "$namespace\*"
foreach($folder in $nameSpaceFolders){
    $targets = Get-DfsnFolderTarget -Path $folder.Path
    $alltargets = @($alltargets + @($targets))
}

Write-Host "`nUpdating DFS folder targets..."
foreach($share in $shares){
    $shareName = [string]$share
    $theseTargets = $alltargets | Where-Object TargetPath -Match "\\$($shareName)$"
    $disableTargets = $theseTargets | Where-Object TargetPath -match "\\$($disableTarget)[-.\\]"
    $enableTargets = $theseTargets | Where-Object TargetPath -match "\\$($enableTarget)[-.\\]"
    foreach($target in $disableTargets){
        Write-Host "    disabling DFS path $($target.Path) -> $($target.TargetPath)"
        $null = Set-DfsnFolderTarget -Path $target.Path -TargetPath $target.TargetPath -State Offline
    }
    foreach($target in $enableTargets){
        Write-Host "     enabling DFS path $($target.Path) -> $($target.TargetPath)`n"
        $null = Set-DfsnFolderTarget -Path $target.Path -TargetPath $target.TargetPath -State Online
    }
}
