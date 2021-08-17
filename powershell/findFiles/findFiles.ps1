### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$extension
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$sources = api get protectionSources?rootNodes

"Parent,Object,Path" | Out-File -FilePath foundFiles.csv

$results = api get "/searchfiles?filename=$($extension)"
$results = api get "restore/files?paginate=true&pageSize=1000&search=$($extension)"
$oldcookie = $null
while($True){
    if($results.files.count -gt 0){
        $output = $results.files | where-object { $_.isFolder -ne $True -and $_.filename -match $extension+'$'} |
                        Sort-Object -Property {$_.protectionSource.name}, {$_.filename} |
                        ForEach-Object {
                            $objectName = $_.protectionSource.name
                            $fileName = $_.filename
                            $parentName = ''
                            $parentId = $_.protectionSource.parentId
                            if($parentId){
                                $parent = $sources | Where-Object {$_.protectionSource.id -eq $parentId}
                                if($parent){
                                    $parentName = $parent.protectionSource.name
                                }
                            }
                            write-host ("{0},{1},{2}" -f $parentName, $objectName, $fileName)
                            "{0},{1},{2}" -f $parentName, $objectName, $fileName | Out-File -FilePath foundFiles.csv -Append
                        }
    }else{
        break
    }
    if($results.paginationCookie){
        $oldcookie = $results.paginationCookie
        while($results.paginationCookie -eq $oldcookie -and $results){
                $results = api get "restore/files?paginate=true&pageSize=1000&paginationCookie=$($results.paginationCookie)&search=$($extension)"
                if(! $results){
                    "retrying..."
                    Start-Sleep 2
                }
        }
    }else{
        break
    }
}

"`nsaving results to foundFiles.csv"
