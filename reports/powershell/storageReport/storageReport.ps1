[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',          # username (local or AD)
    [Parameter()][string]$domain = 'local',             # local or AD domain
    [Parameter()][switch]$useApiKey,                    # use API key for authentication
    [Parameter()][string]$password,                     # optional password
    [Parameter()][switch]$noPrompt,                     # do not prompt for password
    [Parameter()][string]$tenant,                       # org to impersonate
    [Parameter()][switch]$mcm,                          # connect through mcm
    [Parameter()][string]$mfaCode = $null,              # mfa code
    [Parameter()][switch]$emailMfaCode,                 # send mfa code via email
    [Parameter()][string]$clusterName = $null,          # cluster to connect to via helios/mcm
    [Parameter()][switch]$includeArchives,              # include archive stats
    [Parameter()][ValidateSet('KiB','MiB','GiB','TiB','MB','GB','TB')][string]$unit = 'MiB',
    [Parameter()][string]$smtpServer, # outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, # outbound smtp port
    [Parameter()][array]$sendTo, # send to address
    [Parameter()][string]$sendFrom # send from address
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$conversion = @{'Kib' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024; 'MB' = 1000 * 1000; 'GB' = 1000 * 1000 * 1000; 'TB' = 1000 * 1000 * 1000}
function toUnits($val){
    return "{0:n1}" -f ($val/($conversion[$unit]))
}

$cluster = api get cluster
$storageDomains = api get viewBoxes

$today = get-date
$date = $today.ToString()
$fileDate = $date.Replace('/','-').Replace(':','-').Replace(' ','_')

$csvFile = "storageReport_$($cluster.name)_$fileDate.csv"

$title = "Storage Report for $($cluster.name)"

$html = '<html>
<head>
    <style>
        p {
            color: #555555;
            font-family:Arial, Helvetica, sans-serif;
        }
        span {
            color: #555555;
            font-family:Arial, Helvetica, sans-serif;
        }
        

        table {
            font-family: Arial, Helvetica, sans-serif;
            color: #333333;
            font-size: 0.75em;
            border-collapse: collapse;
            width: 100%;
        }

        tr {
            border: 1px solid #F1F1F1;
        }

        td,
        th {
            width: 13%;
            text-align: left;
            padding: 6px;
        }

        tr:nth-child(even) {
            background-color: #F1F1F1;
        }
    </style>
</head>
<body>
    
    <div style="margin:15px;">
            <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAARgAAAAoCAMAAAASXRWnAAAC8VBMVE
            WXyTz///+XyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyTyXyT
            yXyTyXyTyXyTyXyTwJ0VJ2AAAA+nRSTlMAAAECAwQFBgcICQoLDA0ODxARExQVFhcYGRobHB0eHy
            EiIyQlJicoKSorLC0uLzAxMjM0NTY3ODk6Ozw9Pj9AQUNERUZHSElKS0xNTk9QUVJTVFVWV1hZWl
            tcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9foCBgoOEhYaHiImKi4yNjo+QkZKTlJ
            WWl5iZmpucnZ6foKGio6SlpqeoqaqrrK2ur7CxsrO0tba3uLm6u7y9vr/AwcLDxMXGx8jJysvMzc
            7Q0dLT1NXW19jZ2tvc3d7f4OHi4+Xm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+drbbjAAACOZJRE
            FUaIHtWmlcVUUUv6alIgpiEGiZZIpiKu2i4obhUgipmGuihuZWiYmkRBu4JJVappaG5VJRUWrllq
            ZWivtWVuIWllHwShRI51PvnjP33pk7M1d579Gn/j8+zDnnf2b5v3tnu2g1/ocUmvuPRasx83cVu1
            zFB5endtWUCHgoM/+0y1V64sOZcXVlhMDpWXdLM+PmPnmdZTVJeLCPiL6Jd9jT6nfo2y+hH4vE/h
            Fcj6bP6uhcqxvxfYzOdsxOb6gYm39qdrRmE6bBxB2EQWHOXfLBvVvMsIqWdBEYzYvcgWRJ6nS3f5
            +/YSWXEQVeYJPqpXx5XkaaalFuOu22h2E5UVkrIadaAyXFXTwbKh1cw0J3bCgvzFO/CRWtuk3IjP
            lKYK23C7ga3IFCblPwp1HrNvUAyH1W0tRzKlIbk/OmbpbX04uNHGp1/9j6MxMMxUNSYXbqoTJWmF
            t3yCqqHGVLzJK2l8qTtoOzldBqD/C/Ra3hDgOYZKTU2awmpZgVbwG7udWGEvovHYXFHIkuYzHECN
            Pzb0VNy9g8/60KVh5X/QbwtRCajQH//GsQ5k7KCTzqQGprVrwW7HC9GOKQQMhpP30UpWiIM0XYZQ
            gcsYR50Mo9vj73vS9+sOy1Vl6A5S7auXJ53v4Lpr2Trf9LcN0utNsZ/K9Ra4iy++XGE+h3zGGQaV
            bFn+n2lWZQ7q/6id04iW/fI2idFTp4CAOdTWHuNFWZQCf7luMOGr4e9jxCXu1WBxw3Ja03XJs8FG
            ZFdBcbusY2NRKM2k9mD32oXwKLxIGRTMWsMFpon14PAGKTynX/9z17ot27Z23KxyeMLLT1bw6hHT
            SECaTLTOWUmgxt3B/ofcxwLKfdXM2+JH0MtTI8E2aqwLLQDWsuH3+9A0kHJwwDWKC2ifwAF9Z8L+
            dtj87TmikMnTkONOfTg/PAHU7NUVSBQbZWcqjf2vhURZiXHMZ7BBi/RzhQEAphQi7q/l2ShA7Y5S
            L2QdDOoDPSFCYBHQfF3+UZQlwDaDkAJybSSWBl0FZMh4+EuRcIl8Qtg4AqC6NlY58/Zlyvo2uaZg
            rzEz6wN0ryWyY2tlU1TML6CENDDdtHwswCQpqaYKLqwmg/Y5/7mo5O6Niil1GYOPQMkOab8MMN5Q
            fSIO5Mjxumj4T5To+X3gDlsUuXvQV4e0nOyEg70wNhInDUZfWp7Y8rbBnsy1EYnKI3SdMt4AxDu2
            kHfRmjqekbYWrrBwuSD+V3CIc9k7jJwRNhtCewqnXUpAtgHBggjP8l8EQpO4hYB6xsRfQ4ROdQyz
            fChELHZuvFaGLHsWiW6okwdBtKEsHoj8YKDIEwuLf7Udk/RL2/FINFPAbRvdTyjTA3/6PHM/Vioi
            AMITMYqkfCNMDJ4aJ+mgwAJjlXC0MgTKbjo2AAd/OHVeHQSj1cQedvFKamwGoqEeYpZZMBJXp8iV
            4MPCNR5mWL6pEwWi9i/pybsWgcS0GYfHD1V/YPMQZYi5Vx3HLcjwYKk9I7nkdcmkSY9x/gSQnx5j
            r4ox7HQ3D4nkvlFwEXyk1lzJ2nh8JouVjP49pELEw2AiDMCfDdp8xGzASWeun8AOIJrDAqXO2sdC
            GeEnAXQG+tQpuEAUIad3/uF8ps4qUw1+NqWjIEp9lvzAAIg5NHc2U2Yh6wRirj8yE+2hfCkMtBSB
            hh664JP9zhkI2Gw0NhtPvZZisamX4QBtbvypvV2YDFkPuIMj4X4mPR8FIY0h4J9XGvLbs3GY9EYx
            fuqTBaGtMqs5GzhLlytX03PhGPKuOvQNw3T0ypselagPYrkvbwNVtBLY+F0faYra5mvCAMvrD3OG
            W78TywnlbGcQf2MBreCfOzeRprUIGeYynCmx4Ac/B5uvJ5LkzoFdrqSdYLwuC14NVWJZy31avStx
            DvgAYKM6pbLx5dpkiEWdqmPYeoqFpWrb1NtY4fPAQ4fHQb3g+tAXekt8Jow2gD3EUsCIPTqtPp3+
            qi/ALZjbowhVcGs8KIp4dmEmGmOTb7hOyRAjUmQJE+ol4IQzs7l/OBMDj3H3XO1kJwIgxXhHGvdI
            Bry/v7GDcmS4RZpAf6QjEZWd4Ikw4VDeZ8IEwTbK2dczoedUmWIsrL7kNhtO7M9TMF3EjGQ5HuH7
            wRBpf+8ZwPT9c4Ma+/SgfxNsol7vN1tMYeGx8DfSmMdl1GoU0Y2LjjS0Z3lN4IM1spDL6t9MCtxK
            3IypUG4TMVKTRMnwqjabV6ZeVtK9i9S0fBnny8QsXTPl2tqkcYnDit3QOLO1KHG0V6TTdQwkrFUL
            Jh+1gYGfA8eoZa1SOMfrOr4zsxKcnt/pyWW9AHub3AisXAb6bjPxBmMyQvpVY1CUPPUmSD/Wszbp
            jHUGsRsspibawkqlhv01P9wryITRq3a9UkjHlBVsR9GemAM4e1Vza+IOWwAoYto97Zlq8qwjzj3G
            0pwldikysNR3UJo42mgyNfD6pDY7F5hs88OQZXUs/5LGM/E5ljfKXdztRbFWFyAkPsaOxvpQS1im
            jBITxiaO4/2OSVgGoXRnvZUIH8smHetPR566wlcpXFjzGdZO+KjKmZq8zPuOSon4fCVJSU2VHx60
            wjI6OEqGEdY6pPGC1T1Tq3V+5UqmBtYXWh18yiMDGcMMMUdekYgpQRDhT2UhQ/dCiE2X0twkxQCa
            MNKJY1XtyPr+WWDdI+PsuztoGztdAHXL6WUGukw6ALkPKJmnF5OFPxRnAJv0QYuA/Y3TwW2FW2Ca
            OFrRFbXxMm1PP0nwJrXw8bB7/RiF82W4LfOFa0dRDmDaTMVRK2cv+nh10X/oXLD64sdzgLg2eleM
            5n+x+8Tu9wg3Yt6yyrqFH6Ea6LXyQJFFjlMiW5S93+YlPsl5TDPkbHGLxfGi7J58ehtdO9MzQBcN
            HXXaEIRZB+GCvgv9sL/7UZNGjhzlMlLtefhdsXDG6kqRCd9tnh8y5X6dmC3NHS83a73LX2/4lATN
            64iLlEjZk8aaIETyZb3Rw9Y3oah/Rp42KDhHqj3v18hKy9AZ+u6Sjzs6g/e1NGbd5Vo8a/916SKO
            8LK0YAAAAASUVORK5CYII=" style="width:180px">
        <p style="margin-top: 15px; margin-bottom: 15px;">
            <span style="font-size:1.3em;">'

$html += $title
$html += '</span>
<span style="font-size:1em; text-align: right; padding-right: 2px; float: right;">'
$html += $date
$html += "</span>
</p>
<table>
<tr>
    <th>Job/View Name</th>
    <th>Tenant</th>
    <th>Environment</th>
    <th>Origination</th>
    <th>Storage Target</th>
    <th>$unit Logical</th>
    <th>$unit Ingested</th>
    <th>$unit Consumed</th>
    <th>$unit Written</th>
    <th>$unit Unique</th>
    <th>Dedup Ratio</th>
    <th>Compression</th>
    <th>Reduction</th>
    <th>Storage Domain</th>
    <th>Resiliency Setting</th>
</tr>"

"Job/View Name,Tenant,Environment,Origination,Storage Target,$unit Logical,$unit Ingested,$unit Consumed,$unit Written,$unit Unique,Dedup Ratio,Compression,Reduction,Storage Domain,Resiliency Setting" | Out-File -FilePath $csvFile

$jobs = api get protectionJobs?allUnderHierarchy=true
$vaults = api get vaults | Where-Object {$_.usageType -eq 'kArchival'}

$nowMsecs = [int64]((dateToUsecs) / 1000)
$monthsAgoMsecs = [int64]((timeAgo 3 months) / 1000)
if($includeArchives){
    $vaultStats = @()
    foreach($vault in $vaults){
        $externalTargetStats = api get "reports/dataTransferToVaults?endTimeMsecs=$nowMsecs&startTimeMsecs=$monthsAgoMsecs&vaultIds=$($vault.id)"
        if($externalTargetStats -and $externalTargetStats.PSObject.Properties['dataTransferSummary'] -and $externalTargetStats.dataTransferSummary.Count -gt 0){
            $vaultStats = @($vaultStats + @{
                'vaultName' = $vault.name
                'stats' = $externalTargetStats
            })
        }
    }
}


function processStats($stats, $name, $environment, $location, $tenant, $sd){
        $rs = ''
        $sdName = ''
        if($sd){
            $sdName = $sd.name
            if($sd.storagePolicy.numFailuresTolerated -eq 0){
                $rs = 'RF 1'
            }else{
                $rs = 'RF 2'
            }
            if($sd.storagePolicy.PSObject.Properties['erasureCodingInfo']){
                $rs = "EC $($sd.storagePolicy.erasureCodingInfo.numDataStripes):$($sd.storagePolicy.erasureCodingInfo.numCodedStripes)"
            }
        }
        $logicalBytes = $stats[0].stats.totalLogicalUsageBytes
        $dataIn = $stats[0].stats.dataInBytes
        $dataInAfterDedup = $stats[0].stats.dataInBytesAfterDedup
        $dataWritten = $stats[0].stats.dataWrittenBytes
        $consumedBytes = $stats[0].stats.storageConsumedBytes
        $uniquBytes = $stats[0].stats.uniquePhysicalDataBytes
        if($dataInAfterDedup -gt 0 -and $dataWritten -gt 0){
            $dedup = [math]::Round($dataIn/$dataInAfterDedup,1)
            $compression = [math]::Round($dataInAfterDedup/$dataWritten,1)
        }else{
            $dedup = 0
            $compression = 0
        }
        if($consumedBytes -gt 0){
            $reduction = [math]::Round($dataIn / $dataWritten, 1)
        }else{
            $reduction = 0
        }
        $consumption = toUnits $consumedBytes
        $logical = toUnits $logicalBytes
        $dataInUnits = toUnits $dataIn
        $dataWrittenUnits = toUnits $dataWritten
        $uniqueUnits = toUnits $uniquBytes

        Write-Host ("{0,35}: {1,11:f2} {2}" -f $name, $consumption, $unit)

        """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",""{10}"",""{11}"",""{12}"",""{13}"",""{14}""" -f $name,
                                                 $tenant,
                                                 $environment,
                                                 $location,
                                                 'Local',
                                                 $logical,
                                                 $dataInUnits,
                                                 $consumption,
                                                 $dataWrittenUnits,
                                                 $uniqueUnits,
                                                 $dedup,
                                                 $compression,
                                                 $reduction,
                                                 $sdName,
                                                 $rs | Out-File -FilePath $csvFile -Append
        return ("<td>{0}</td>
        <td>{1}</td>
        <td>{2}</td>
        <td>{3}</td>
        <td>{4}</td>
        <td>{5}</td>
        <td>{6}</td>
        <td>{7}</td>
        <td>{8}</td>
        <td>{9}</td>
        <td>{10}</td>
        <td>{11}</td>
        <td>{12}</td>
        <td>{13}</td>
        <td>{14}</td>
        </tr>" -f $name,
                  $tenant,
                  $environment,
                  $location,
                  'Local',
                  $logical,
                  $dataInUnits,
                  $consumption,
                  $dataWrittenUnits,
                  $uniqueUnits,
                  $dedup,
                  $compression,
                  $reduction,
                  $sdName,
                  $rs)
    
}

function processExternalStats($vaultName, $storageConsumed, $name, $environment, $location, $tenant){
    $consumption = toUnits $storageConsumed

    """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",""{10}"",""{11}""" -f $name,
                                             $tenant,
                                             $environment,
                                             $location,
                                             $vaultName,
                                             '',
                                             '',
                                             $consumption,
                                             '',
                                             '',
                                             '',
                                             '',
                                             '' | Out-File -FilePath $csvFile -Append
    return ("<td>{0}</td>
    <td>{1}</td>
    <td>{2}</td>
    <td>{3}</td>
    <td>{4}</td>
    <td>{5}</td>
    <td>{6}</td>
    <td>{7}</td>
    <td>{8}</td>
    <td>{9}</td>
    <td>{10}</td>
    <td>{10}</td>
    <td>{11}</td>
    </tr>" -f $name,
              $tenant,
              $environment,
              $location,
              $vaultName,
              '-',
              '-',
              $consumption,
              '-',
              '-',
              '-',
              '-',
              '-')
}

# view ProtectoinJobs

$msecsBeforeCurrentTimeToCompare = 7 * 24 * 60 * 60 * 1000
$cookie = ''
$viewJobStats = @{'statsList'= @()}
while($True){
    $theseStats = api get "stats/consumers?consumerType=kViewProtectionRuns&msecsBeforeCurrentTimeToCompare=$($msecsBeforeCurrentTimeToCompare)&cookie=$cookie"
    if($theseStats -and $theseStats.PSObject.Properties['statsList']){
        $viewJobStats['statsList'] = @($viewJobStats['statsList'] + $theseStats.statsList)
    }
    if($theseStats -and $theseStats.PSObject.Properties['cookie']){
        $cookie = $theseStats.cookie
    }else{
        $cookie = ''
    }
    if($cookie -eq ''){
        break
    }
}

Write-Host "  Local ProtectionJobs..."

# local backup stats
$msecsBeforeCurrentTimeToCompare = 7 * 24 * 60 * 60 * 1000
$cookie = ''
$localStats = @{'statsList'= @()}
while($True){
    $theseStats = api get "stats/consumers?consumerType=kProtectionRuns&msecsBeforeCurrentTimeToCompare=$($msecsBeforeCurrentTimeToCompare)&cookie=$cookie"
    if($theseStats -and $theseStats.PSObject.Properties['statsList']){
        $localStats['statsList'] = @($localStats['statsList'] + $theseStats.statsList)
    }
    if($theseStats -and $theseStats.PSObject.Properties['cookie']){
        $cookie = $theseStats.cookie
    }else{
        $cookie = ''
    }
    if($cookie -eq ''){
        break
    }
}
$localStats['statsList'] = @($localStats['statsList'] + $viewJobStats.statsList)

foreach($job in $jobs | Sort-Object -Property name){
    $sd = $null
    if($job.viewBoxid){
        $sd = $storageDomains | Where-Object {$_.id -eq $job.viewBoxId}
    }

    $stats = $null
    if($job.PSObject.Properties['tenantId']){
        $tenant = $job.tenantId.Substring(0, $job.tenantId.length - 1)
    }else{
        $tenant = ''
    }
    if($job.policyId.split(':')[0] -eq $cluster.id){
        $stats = $localStats.statsList | Where-Object {$_.id -eq $job.id -or $_.name -eq $job.name}
        if($stats){
            foreach($stat in $stats){
                $html += processStats $stat $job.name $job.environment.subString(1) 'Local' $tenant $sd
            }
        }
    }
    if($includeArchives){
        foreach($vaultStat in $vaultStats){
            foreach($vault in $vaultStat.stats.dataTransferSummary){
                $vaultName = $vault.vaultName
                $thisJobStats = $vault.dataTransferPerProtectionJob | Where-Object {$_.protectionJobName -eq $job.name}
                if($thisJobStats){
                    foreach($thisJobStat in $thisJobStats){
                        $storageConsumed = $thisJobStat.storageConsumed
                        $html += processExternalStats $vaultName $storageConsumed $job.name $job.environment.subString(1) 'Local' $tenant
                    }
                }
            }
        }
    }
}

Write-Host "  Replicated Jobs..."

# replica backup stats
$cookie = ''
$replicaStats = @{'statsList'= @()}
while($True){
    $theseStats = api get "stats/consumers?consumerType=kReplicationRuns&msecsBeforeCurrentTimeToCompare=$($msecsBeforeCurrentTimeToCompare)&cookie=$cookie"
    if($theseStats -and $theseStats.PSObject.Properties['statsList']){
        $replicaStats['statsList'] = @($replicaStats['statsList'] + $theseStats.statsList)
    }
    if($theseStats -and $theseStats.PSObject.Properties['cookie']){
        $cookie = $theseStats.cookie
    }else{
        $cookie = ''
    }
    if($cookie -eq ''){
        break
    }
}
$replicaStats['statsList'] = @($replicaStats['statsList'] + $viewJobStats.statsList)

foreach($job in $jobs | Sort-Object -Property name){
    $sd = $null
    if($job.viewBoxid){
        $sd = $storageDomains | Where-Object {$_.id -eq $job.viewBoxId}
    }
    $stats = $null
    if($job.PSObject.Properties['tenantId']){
        $tenant = $job.tenantId.Substring(0, $job.tenantId.length - 1)
    }else{
        $tenant = ''
    }
    if($job.policyId.split(':')[0] -ne $cluster.id){
        $stats = $replicaStats.statsList | Where-Object {$_.id -eq $job.id -or $_.name -eq $job.name}
        if($stats){
            foreach($stat in $stats){
                $html += processStats $stat $job.name $job.environment.subString(1) 'Replicated' $tenant $sd
            }
        }
    }
}

Write-Host "  Unprotected Views..."
$views = api get -v2 "file-services/views?includeTenants=true&includeStats=false&includeProtectionGroups=true"

foreach($view in $views.views | Sort-Object -Property name){
    $sd = $null
    if($view.storageDomainId){
        $sd = $storageDomains | Where-Object {$_.id -eq $view.storageDomainId}
    }
    $stats = $null
    if($view.PSObject.Properties['tenantId']){
        $tenant = $view.tenantId.Substring(0, $view.tenantId.length - 1)
    }else{
        $tenant = ''
    }
    if($cluster.clusterSoftwareVersion -le '6.5.1b' -or $null -eq $view.viewProtection){
        $stats = api get "stats/consumers?consumerType=kViews&consumerIdList=$($view.viewId)"
        if($stats.statsList){
            $html += processStats $stats $view.name 'View' 'Local' $tenant $sd
        }
    }
}

$html += "</table>                
</div>
</body>
</html>"

$html | Out-File -FilePath "storageReport_$($cluster.name)_$fileDate.html"

Write-Host "`nsaving report as storageReport_$($cluster.name)_$fileDate.html"
Write-Host "also as csv file $csvFile"

if($smtpServer -and $sendTo -and $sendFrom){
    Write-Host "`nsending report to $([string]::Join(", ", $sendTo))`n"

    # send email report
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject $title -BodyAsHtml $html -WarningAction SilentlyContinue
    }
}
