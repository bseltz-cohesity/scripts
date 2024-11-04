$excludedVolumes = @('D', 'E')
$volumes = Get-Volume | Where-Object {$_.DriveLetter -ne $null -and $_.DriveType -eq 'Fixed' -and $_.DriveLetter -notin $excludedVolumes}

foreach($volume in $volumes){
    $driveLetter = $volume.DriveLetter
    $s1 = (Get-WmiObject -List Win32_ShadowCopy).Create("$($driveLetter):\", 'ClientAccessible')
    $s2 = Get-WmiObject Win32_ShadowCopy | Where-Object {$_.ID -eq $s1.ShadowID}
    $d  = $s2.DeviceObject + '\\'
    cmd /c mklink /d "$($driveLetter):\shadowcopy" $d
    $s2.id | Out-File -FilePath "vssid-$($driveLetter)"
}

