#!/usr/bin/pwsh
### create_anf_snap.ps1
# Creates a snapshot on a given AzureNetappFiles volume
# Parameter:
#	AppID				Azure-ApplicationID
#	TenantID			Azure-TenantID
#	SecretString		The Secret phrase from the Application (Value)
#   
#   ResourceGroupName   Name of the Azure ResourceGroup
#   Region              Azure Region
#	AccountName			ANF Account
#	PoolName			ANF PoolName
#   VolumeName			ANF VolumeName
#   SnapshotName        New SnapshotName
#
# All Values above can be obtained from Azure portal.
#
# Author Christoph Linden @Cohesity

### process commandline arguments
[CmdletBinding()]
param (
   [Parameter(Mandatory = $True)][string]$AppID, 				#ApplicationID
   [Parameter(Mandatory = $True)][string]$TenantID,				#TenantID
   [Parameter(Mandatory = $True)][string]$SecretString,			#SecretString für Application SecretID
   [Parameter(Mandatory = $True)][string]$ResourceGroupName,    #ResourceGroupName
   [Parameter(Mandatory = $True)][string]$Region,               #Region
   [Parameter(Mandatory = $True)][string]$AccountName,			#AccountName 
   [Parameter(Mandatory = $True)][string]$PoolName,				#PoolName
   [Parameter(Mandatory = $True)][string]$VolumeName,			#VolumeName
   [Parameter(Mandatory = $True)][string]$SnapshotName			#SnapshotName
)

### turn of colors in output
$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

#Connect to Azure
Write-Output "Connecting to Azure ApplicationID: $AppID"
try {
	$SecureStringPwd = $SecretString | ConvertTo-SecureString -AsPlainText -Force
	$pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AppID, $SecureStringPwd
	$tempobj = Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $TenantID -Verbose:$false
}
catch {
	Write-Error "Could not connect to Azure ApplicationID $AppID"
	Write-Error $_
	Write-Error $_.ScriptStackTrace -ErrorAction Stop
}

#Check if Snapshot still exists - delete it
Write-Output "Checking for old snapshot $SnapshotName on volume $AccountName/$PoolName/$VolumeName"
$SnapshotObject = Get-AzNetAppFilesSnapshot -ResourceGroupName $ResourceGroupName -AccountName $AccountName -PoolName $PoolName -VolumeName $VolumeName -SnapshotName $SnapshotName -Verbose:$false

if ($SnapshotObject -ne $null) {
	Write-Output "Old snapshot found. Deleting ..."
	try {
		Remove-AzNetAppFilesSnapshot -ResourceGroupName $ResourceGroupName -AccountName $AccountName -PoolName $PoolName -VolumeName $VolumeName -SnapshotName $SnapshotName
	}
	catch {
		Write-Error "Could not delete existing old snapshot $SnapshotName on volume $AccountName/$PoolName/$VolumeName"
		Write-Error $_
		Write-Error $_.ScriptStackTrace -ErrorAction Stop
	}
	Write-Output "Snapshot deleted."
}

#Create new Snapshot with name
Write-Output "Creating new snapshot $SnapshotName on volume $AccountName/$PoolName/$VolumeName"
try {
	$tempsnap = New-AzNetAppFilesSnapshot -ResourceGroupName $ResourceGroupName -l $Region -AccountName $AccountName -PoolName $PoolName -VolumeName $VolumeName -SnapshotName $SnapshotName -Verbose:$false
}
catch {
	Write-Error "Could not create snapshot $SnapshotName on volume $AccountName/$PoolName/$VolumeName"
	Write-Error $_
	Write-Error $_.ScriptStackTrace -ErrorAction Stop
}
