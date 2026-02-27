cd $PSScriptRoot

# vSphere parameters
$vCenter = 'myvcenter.mydomain.net'
$creds = Import-Clixml -Path .\mycreds.xml
$vms = @(
    'my-helios-vm1',
    'my-helios-vm2',
    'my-helios-vm3',
    'my-helios-vm4'
)

# Cohesity cluster parameters
$cluster = 'mycohesitycluster.mydomain.net'
$username = 'myuser'
$pg = 'myVMprotectionGroup'

# Helios parameters
$heliosEndpoint = 'myhelios.mydomain.net'
$heliosUsername = 'admin'

# tuning parameters
$sleepTime = 30  # sleep between shutdown queries
$timeout = 3600  # give up waiting for shutdown/startup
$pgSleep = 60    # sleep between protection run queries
$waitForHelios = $True
$logFile = "log-heliosVEbackup.txt"

function output($text, $warn=$False, $quiet=$False){
    if($quiet -eq $False){
        if($warn -eq $True){
            Write-Host $text -ForegroundColor Yellow
        }else{
            Write-Host $text
        }
    }
    $text | Out-File -FilePath $logFile -Append
}

$startTime = Get-Date
"Backup script started at $startTime" | Out-File -FilePath $logFile

# validate cached Helios credentials
if($waitForHelios -eq $True){
    output "`nConnecting to Helios..."
    apiauth -vip $heliosEndpoint -username $heliosUsername -helios
    if(!$cohesity_api.authorized){
        output "`nUnable to authenticate to Helios`n" $True
        output "Script ended at $(Get-Date)" $False $True
        exit 1
    }
}

# connect to vSphere
output "`nConnecting to vCenter..."

$null = Connect-VIServer -Server $vCenter -Credential $creds -Force

# record mac addresses
output "`nRecording mac addresses:`n"
foreach($vm in $vms){
    $thisVM = Get-VM -Name $vm
    $nics = $thisVM | Get-NetworkAdapter
    foreach($nic in $nics){
        output "    $($vm): $($nic.Name): $($nic.MacAddress)"
    }
}

# shutdown VMs
output "`nShutting down VMs...`n"
foreach($vm in $vms){
    output "    $vm"
    $null = Shutdown-VMGuest -VM $vm -Confirm:$false -ErrorAction SilentlyContinue
}

# wait for poweroff
output "`nWaiting for shutdowns to complete..."
while($True){
    $allPoweredOff = $True
    foreach($vm in $vms){
        $thisVM = Get-VM -Name $vm
        $powerState = $thisVM.PowerState
        if($powerState -ne 'PoweredOff'){
            $allPoweredOff = $False
        }
    }
    if($allPoweredOff -eq $True){
        break
    }else{
        Start-Sleep $sleepTime
    }
    $now = Get-Date
    $elapsed = ($now - $startTime).TotalSeconds
    if($elapsed -ge $timeout){
        output "`nTimed out waiting for VMs to PowerOff`n" $True
        output "Script ended at $(Get-Date)" $False $True
        exit 1
    }
}

# run protection group
output "`nStarting backup..."
./backupNow.ps1 -vip $cluster -username $username -jobName $pg -noCache -sleepTimeSecs $pgSleep -wait
$backupResult = $LASTEXITCODE
output "`nBackup completed with exit code: $backupResult"

# power on VMs
output "`nStarting VMs...`n"
foreach($vm in $vms){
    output "    $vm"
    $null = Start-VM -VM $vm -RunAsync
}

# wait for Helios to start
if($waitForHelios -eq $True){
    output "`nWaiting for Helios to start..."
    $startWaiting = Get-Date
    . $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)
    apidrop -quiet
    while($cohesity_api.authorized -ne $True){
        Start-Sleep $sleepTime
        apiauth -vip $heliosEndpoint -username $heliosUsername -helios -quiet -noPrompt -timeout $sleepTime
        if($cohesity_api.authorized -eq $True){
            output "`nHelios operational!`n"
            output "Script ended at $(Get-Date)" $False $True
            exit 0
        }
        $now = Get-Date
        $elapsed = ($now - $startWaiting).TotalSeconds
        if($elapsed -ge $timeout){
            output "`nTimed out waiting for Helios`n" $True
            output "Script ended at $(Get-Date)" $False $True
            exit 1
        }
    }
}else{
    output "Script ended at $(Get-Date)" $False $True
    exit 0
}
