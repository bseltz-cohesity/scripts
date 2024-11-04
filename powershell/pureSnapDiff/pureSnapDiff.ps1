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
    [Parameter()][int64]$blockSize1 = 10240,  # block size in KB - e,g, 10240, 1024, 512, 256
    [Parameter()][int64]$blockSize2 = 0,   # block size in KB - e,g, 10240, 1024, 512, 256
    [Parameter()][ValidateSet('MiB','GiB')][string]$unit = 'GiB',
    [Parameter()][switch]$createSnapshot,
    [Parameter()][switch]$storePassword,
    [Parameter()][int]$stopAfter,
    [Parameter()][string]$version
)

$conversion = @{'MiB' = (1024 * 1024); 'GiB' = (1024 * 1024 * 1024)}
function toUnits($val){
    return "{0:n1}" -f ($val/($conversion[$unit]))
}

# default $length = 1 TiB / $lengthDivisor = 1
$length = 1099511627776 / $lengthDivisor

. $(Join-Path -Path $PSScriptRoot -ChildPath pure-api.ps1)

if($diffTest -and !$firstSnapshot){
    Write-Host "-firstSnapshot is required for diffTest" -foregroundcolor Yellow
    exit 1
}

# authenticate
if($storePassword){
    papiauth -endpoint $pure -username $username -password $password -version $version -storePassword
}else{
    papiauth -endpoint $pure -username $username -password $password -version $version
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

    # blockSize1
    $diff1 = 0
    $duration1 = 0

    # blockSize2
    if($blockSize2 -gt 0){
        $diff2 = 0
        $duration2 = 0
    }

    "`nDiff Started"
    
    $counted = 0
    While($offSet -lt $volumeSize){
        # blockSize1
        $diffStart = Get-Date
        Write-Host "Querying blocks (block size: $blockSize1 KiB) - offset $($offset / (1024 * 1024 * 1024)) GiB"
        $volumediff = papi get "volume/$($secondSnapshot)/diff?base=$($firstSnapshot)`&block_size=$($blockSize1 * 1024)`&length=$($length)`&offset=$($offset)"
        $diffEnd = Get-Date
        $diffSeconds = ($diffEnd - $diffStart).TotalSeconds
        $duration1 += $diffSeconds
        if($blockSize2 -and $volumeDiff.Count -gt 0){
            Write-Host "Querying blocks (block size: $blockSize2 KiB) - offset $($offset / (1024 * 1024 * 1024)) GiB"
        }
        foreach($result in $volumeDiff){
            $diff1 += $result.length
            if($blockSize2){
                $diffStart = Get-Date
                $volumediff2 = papi get "volume/$($secondSnapshot)/diff?base=$($firstSnapshot)`&block_size=$($blockSize2 * 1024)`&length=$($result.length)`&offset=$($result.offset)"
                $diffEnd = Get-Date
                $diffSeconds = ($diffEnd - $diffStart).TotalSeconds
                $duration2 += $diffSeconds
                foreach($result2 in $volumeDiff2){
                    Write-Host "$($result2.length)        $(($result2.offset / (1024 * 1024 * 1024)))"
                    $diff2 += $result2.length
                }
            }
        }

        # blockSize2
        # if($blockSize2 -gt 0){
        #     $diffStart = Get-Date
        #     Write-Host "Querying blocks (block size: $blockSize2 KiB) - offset $($offset / (1024 * 1024 * 1024)) GiB"
        #     $volumediff = papi get "volume/$($secondSnapshot)/diff?base=$($firstSnapshot)`&block_size=$($blockSize2 * 1024)`&length=$($length)`&offset=$($offset)"
        #     $diffEnd = Get-Date
        #     $diffSeconds = ($diffEnd - $diffStart).TotalSeconds
        #     $duration2 += $diffSeconds
        #     foreach($result in $volumeDiff){
        #         $diff2 += $result.length
        #     }
        # }

        $offSet += $length
        $counted += 1
        if($stopAfter -and $counted -ge $stopAfter){
            break
        }
    }
    
    "Diff Completed"

    "`n               Volume Size: $(toUnits $volumeSize) $unit"
    "Snapshot Difference (Days): {0:n1}" -f $dayDiff

    # blockSize1
    $changeRatePerDay = $diff1 / $dayDiff
    $pctPerDay = "{0:n1}" -f (100 * $changeRatePerDay / $volumeSize)
    "`n                 BlockSize: $blockSize1 KiB"
    "                  Duration: {0:n0} Seconds" -f $duration1
    "              Data Changed: $(toUnits $diff1) $unit"
    "         Daily Change Rate: $(toUnits $changeRatePerDay) $($unit)/day ($($pctPerDay)%/day)`n"

    # blockSize2
    if($blockSize2 -gt 0){
        $changeRatePerDay = $diff2 / $dayDiff
        $pctPerDay = "{0:n1}" -f (100 * $changeRatePerDay / $volumeSize)
        "                 BlockSize: $blockSize2 KiB"
        "                  Duration: {0:n0} Seconds" -f $duration2
        "              Data Changed: $(toUnits $diff2) $unit"
        "         Daily Change Rate: $(toUnits $changeRatePerDay) $($unit)/day ($($pctPerDay)%/day)`n"
    }
}
papidrop
