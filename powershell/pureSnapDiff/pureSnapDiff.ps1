### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$pure,        # the pure array to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,    # username 
    [Parameter()][string]$password = $null,             # optional, will be prompted if omitted
    [Parameter(Mandatory = $True)][string]$volumeName,  # name of volume to query
    [Parameter()][switch]$listSnapshots,     # list available snapshots and exit
    [Parameter()][switch]$diffTest,          # perform diff test
    [Parameter()][string]$firstSnapshot,     # specify name of first snapshot
    [Parameter()][string]$secondSnapshot,    # specify name of second snapshot
    [Parameter()][string]$deleteSnapshot,    # delete the specified snapshot and exit
    [Parameter()][int64]$lengthDivisor = 1,  # reduce length of diff query by X - e.g. 2, 4, 8
    [Parameter()][int64]$blockSizeMB = 10,   # block size in MB - e,g, 10, 4, 2
    [Parameter()][ValidateSet('MiB','GiB')][string]$unit = 'GiB',
    [Parameter()][switch]$createSnapshot,
    [Parameter()][switch]$storePassword
)

$conversion = @{'MiB' = (1024 * 1024); 'GiB' = (1024 * 1024 * 1024)}
function toUnits($val){
    return "{0:n1}" -f ($val/($conversion[$unit]))
}

$length = 1099511627776 / $lengthDivisor

. $(Join-Path -Path $PSScriptRoot -ChildPath pure-api.ps1)

if($diffTest -and !$firstSnapshot){
    Write-Host "-firstSnapshot is required for diffTest" -foregroundcolor Yellow
    exit 1
}

# authenticate
if($storePassword){
    papiauth -endpoint $pure -username $username -password $password -storePassword
}else{
    papiauth -endpoint $pure -username $username -password $password
}

# get volume
$volume = papi get volume/$volumeName
if(!$volume){
    exit 1
}

# get snapshots for volume
$snaps = papi get volume/$($volumeName)?snap=true

$nowUsecs = dateToUsecs

if($deleteSnapshot){
    $snapToDelete = $snaps | Where-Object name -eq $deleteSnapshot
    if(!$snapToDelete){
        Write-Host "`nSnapshot $deleteSnapshot not found" -foregroundcolor Yellow
        exit 1
    }
    Write-Host "`nDeleting snapshot $deleteSnapshot`n"
    if($eradicate){
        $null = papi delete volume/$($snapToDelete.name)?eradicate=true
    }else{
        $null = papi delete volume/$($snapToDelete.name)
    }
    exit 0
}

if($createSnapshot){
    $newsnap = papi post volume @{'snap' = $True; 'source' = @($volume.name)}
    $secondSnapshot = $newsnap.name
    "`nCreating new snapshot $secondSnapshot"
    exit
}

if($listSnapshots){
    "`nSnapshots:`n"
    foreach($snap in $snaps){
        $createdUsecs = dateToUsecs $snap.created
        $ageUsecs = $nowUsecs - $createdUsecs
        $ageHours = [math]::Round($ageUsecs / (1000000 * 60 * 60), 1)
        "{0}  ({1})  {2} Hours Old" -f $snap.name, $snap.created, $ageHours
    }
    exit 0
}

if($diffTest){
    if($firstSnapshot -notin $snaps.name){
        Write-Host "`nSnapshot $firstSnapshot not found" -foregroundcolor Yellow
        exit 1
    }

    # calculate first snapshot age
    $snap = $snaps | Where-Object name -eq $firstSnapshot
    $createdUsecs = dateToUsecs $snap.created
    $ageUsecs = $nowUsecs - $createdUsecs
    $ageDays = $ageUsecs / (1000000 * 60 * 60 * 24)

    # create new snapshot
    if(!$secondSnapshot){
        $newsnap = papi post volume @{'snap' = $True; 'source' = @($volume.name)}
        $secondSnapshot = $newsnap.name
        "`nCreating new snapshot $secondSnapshot"
        $sageDays = 0
    }else{
        if($secondSnapshot -notin $snaps.name){
            Write-Host "`nSnapshot $secondSnapshot not found" -foregroundcolor Yellow
            exit 1
        }
        $snap = $snaps | Where-Object name -eq $secondSnapshot
        $createdUsecs = dateToUsecs $snap.created
        $ageUsecs = $nowUsecs - $createdUsecs
        $sageDays = $ageUsecs / (1000000 * 60 * 60 * 24)
    }

    # calculate change
    $dayDiff = $ageDays - $sageDays
    $volumeSize = $volume.size
    $offSet = 0
    $blockCount = 0
    $diff = 0
    "`nDiff Started"
    $diffStart = Get-Date
    While($offSet -lt $volumeSize){
        $volumediff = papi get "volume/$($secondSnapshot)/diff?base=$($firstSnapshot)`&block_size=$($blockSizeMB * 1048576)`&length=$($length)`&offset=$($offset)"
        $blockCount += $volumediff.Count
        foreach($result in $volumeDiff){
            $diff = $diff + $result.length
        }
        $offSet += $length
    }
    $diffEnd = Get-Date
    $diffSeconds = ($diffEnd - $diffStart).TotalSeconds
    "Diff Completed"
    "Duration: {0:n0} Seconds" -f $diffSeconds
    
    $changeRatePerDay = $diff / $dayDiff
    $pctPerDay = "{0:n1}" -f (100 * $changeRatePerDay / $volumeSize)
    "`n     Days Elapsed: {0:n1}" -f $dayDiff
    "     Data Changed: $(toUnits $diff) $unit"
    "      Volume Size: $(toUnits $volumeSize) $unit"
    "Daily Change Rate: $(toUnits $changeRatePerDay) $($unit)/day ($($pctPerDay)%/day)`n"
}
papidrop
