### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$cname,
    [Parameter(Mandatory = $True)][string]$oldHost,
    [Parameter(Mandatory = $True)][string]$newHost,
    [Parameter()][string]$newRecord = $newHost,
    [Parameter(Mandatory = $True)][string]$domain
)

# update CNAME to point to DR cluster
"Updating cname record $cname.$domain to point to $newRecord..."
$oldCnameRecord = Get-DnsServerResourceRecord -ZoneName $domain -ComputerName $domain -Name $cname
$newCnameRecord = $oldCnameRecord.Clone()
if($newRecord -match $domain){
    $newCnameRecord.RecordData.HostNameAlias = $newRecord
}else{
    $newCnameRecord.RecordData.HostNameAlias = "{0}.{1}." -f $newRecord, $domain
}
$null = Set-DnsServerResourceRecord -NewInputObject $newCnameRecord -OldInputObject $oldCnameRecord -ZoneName $domain -ComputerName $domain -PassThru

# remove the SPN from old host
"Removing SPN $cname.$domain from $oldHost..."
$spn = "{0}.{1}" -f $cname, $domain
$oldHost = $oldHost.split('.')[0]
Set-ADComputer -Identity $oldHost -ServicePrincipalNames @{Remove="cifs/$spn"}
Set-ADComputer -Identity $oldHost -ServicePrincipalNames @{Remove="cifs/$cname"}

# add the SPN to the new host
"Adding SPN $cname.$domain to $newHost..."
$newHost = $newHost.split('.')[0]
Set-ADComputer -Identity $newHost -ServicePrincipalNames @{Add="cifs/$spn"}
Set-ADComputer -Identity $newHost -ServicePrincipalNames @{Add="cifs/$cname"}

