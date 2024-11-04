$excludedVolumes = @('D', 'E')
$volumes = Get-Volume | Where-Object {$_.DriveLetter -ne $null -and $_.DriveType -eq 'Fixed' -and $_.DriveLetter -notin $excludedVolumes}

foreach($volume in $volumes){
    $driveLetter = $volume.DriveLetter
    $vssid = Get-Content "vssid-$($driveLetter)"
    $vss = Get-WmiObject Win32_ShadowCopy | Where-Object id -eq $vssid
    $vss.Delete()
    Remove-Item -Path "$($driveLetter):\shadowcopy"
    Remove-Item -Path "vssid-$($driveLetter)"
}