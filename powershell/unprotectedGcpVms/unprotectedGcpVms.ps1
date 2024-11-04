# usage:
# ./unprotectedGcpVms.ps1 -vip mycluster `
#                  -username myusername `
#                  -domain mydomain.net `
#                  -sendTo myuser@mydomain.net, anotheruser@mydomain.net `
#                  -smtpServer 192.168.1.95 `
#                  -sendFrom backupreport@mydomain.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$smtpServer, #outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, #outbound smtp port
    [Parameter()][array]$sendTo, #send to address
    [Parameter()][string]$sendFrom #send from address
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# log file
$logFile = $(Join-Path -Path $PSScriptRoot -ChildPath log-unprotectedGcpVms.txt)

# get last seen ID file
$lastIdFile = $(Join-Path -Path $PSScriptRoot -ChildPath lastGcpId.txt)
if(Test-Path $lastIdFile){
    $lastId = (Get-Content $lastIdFile).ToString()
}else{
    $lastId = 0
}
$newLastId = 0

# cluster info
$cluster = api get cluster

# email message
$message = "  New GCP VMs found on $($cluster.name):`n"

# get GCP protection sources
$sources = api get protectionSources?environment=kGCP

foreach($source in $sources){
    $sourceName = $source.protectionSource.name

    # get list of protected VMs
    $protectedGcpVms = api get "protectionSources/protectedObjects?environment=kGCPNative&id=$($source.protectionSource.id)"
    $protectedIds = @($protectedGcpVms.protectionSource.id)

    # get list of projects
    $projects = $source.nodes | Where-Object {$_.protectionSource.gcpProtectionSource.type -eq 'kProject' -and $null -ne $_.nodes}
    foreach($project in $projects){
        $projectName = $project.protectionSource.name

        # get regions
        $regions = $project.nodes
        foreach($region in $regions){
            $regionName = $region.protectionSource.name

            # get subnets
            $subnets = $region.nodes
            foreach($subnet in $subnets){
                $subnetName = $subnet.protectionSource.name

                # get vms
                $vms = $subnet.nodes
                foreach($vm in $vms){
                    $vmId = $vm.protectionSource.id
                    $vmName = $vm.protectionSource.name

                    # report new unprotected vm
                    if($vmId -notin $protectedIds -and $vmId -gt $lastId){
                        $newVMreport = "{0}/{1}/{2}/{3}/{4}" -f $sourceName, $projectName, $regionName, $subnetName, $vmName
                        "  new VM $newVMreport is unprotected"
                        $message += "    $newVMreport`n"
                        if($vmId -gt $newLastId){
                            $newLastId = $vmId
                        }
                    }
                }
            }
        }
    }
}

if($newLastId -ne 0){
    # update log file
    "$(get-date) --------------------------------------------------------------------" | Out-File -FilePath $logFile -Append
    $message | Out-File -FilePath $logFile -Append
    # send email report
    if($smtpServer -and $sendTo -and $sendFrom){
        write-host "`nsending report to $([string]::Join(", ", $sendTo))"
        foreach($toaddr in $sendTo){
            Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject "New Unprotected GCP VMs ($($cluster.name))" -Body $message -WarningAction SilentlyContinue
        }
        $html | out-file "$($cluster.name)-objectreport.html"
    }

    # update last seen ID file
    $newLastId | Out-File -FilePath $lastIdFile

}else{
    "  No new unprotected VMs discovered"
    # update log file
    "$(get-date) --------------------------------------------------------------------" | Out-File -FilePath $logFile -Append
    "  No new unprotected VMs discovered`n" | Out-File -FilePath $logFile -Append
}
