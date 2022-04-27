# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vCenter,
    [Parameter()][array]$vmName,
    [Parameter()][string]$vmList
)

Write-Host "Connecting to vCenter: $vCenter..."
$viServer = connect-VIServer -Server $vCenter -force

# outfile
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "avgVmDiskThoughput-$dateString.csv"

# headings
"VM Name,Average KBps" | Out-File -FilePath $outfileName


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


$vmNames = @(gatherList -Param $vmName -FilePath $vmList -Name 'jobs' -Required $True)

$vms = Get-VM | Where-Object name -in $vmNames

# catch invalid VM names
if($vmNames.Count -gt 0){
    $notfoundVMs = $vmNames | Where-Object {$_ -notin $vms.name}
    if($notfoundVMs){
        Write-Host "VMs not found $($notfoundVMs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

foreach($vm in $vms | Sort-Object -Property name){
    $averageThroughput = (@($vm | Get-Stat -MaxSamples 48 -IntervalSecs 1800 -Stat disk.usage.average | Select-Object Value).Value | Measure-Object -Average).average
    """{0}"",""{1:n2}""" -f $vm.name, $averageThroughput | Tee-Object -FilePath $outfileName -Append 
}

"`nOutput saved to $outfilename`n"
