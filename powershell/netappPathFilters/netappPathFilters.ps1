# usage: [list] | ./netappPathFilters.ps1 -vip mycluster -username myusername -jobName 'My Job' -addInclusions -addExclusions

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to add server to
    [Parameter(ParameterSetName="addInclusions")][switch]$addInclusions,
    [Parameter(ParameterSetName="addExclusions")][switch]$addExclusions,
    [Parameter(Mandatory = $True, ValueFromPipeline = $True)][string[]]$inputList
)

begin{
    # source the cohesity-api helper code
    . ./cohesity-api

    # authenticate
    apiauth -vip $vip -username $username -domain $domain

    # get the protectionJob
    $job = api get protectionJobs | Where-Object {$_.name -ieq $jobName}
    if(!$job){
        Write-Warning "Job $jobName not found!"
        exit
    }

    # get existing filePathFilters
    if(! $job.environmentParameters.nasParameters.PSObject.Properties['filePathFilters']){
        $job.environmentParameters.nasParameters | Add-Member -MemberType NoteProperty -Name filePathFilters -Value (New-Object -TypeName PSObject -Property @{})
    }

    # if we're adding includes, get existing includes
    if($addInclusions -and ! $job.environmentParameters.nasParameters.filePathFilters.PSObject.Properties['protectFilters']){
        $job.environmentParameters.nasParameters.filePathFilters | Add-Member -MemberType NoteProperty -Name protectFilters -Value @()
    }    

    # if we're adding excludes, get existing excludes
    if($addExclusions -and ! $job.environmentParameters.nasParameters.filePathFilters.PSObject.Properties['excludeFilters']){
        $job.environmentParameters.nasParameters.filePathFilters | Add-Member -MemberType NoteProperty -Name excludeFilters -Value @()
    }
}

process{
    foreach($path in $inputList){
        # add item to inclusion list
        if($addInclusions){
            "adding to include list: $path"
            $job.environmentParameters.nasParameters.filePathFilters.protectFilters = $job.environmentParameters.nasParameters.filePathFilters.protectFilters + $path | Sort-Object -Unique
        }
        # or add item to excliusion list
        if($addExclusions){
            "adding to exclude list: $path"
            $job.environmentParameters.nasParameters.filePathFilters.excludeFilters = $job.environmentParameters.nasParameters.filePathFilters.excludeFilters + $path | Sort-Object -Unique
        }
    }
}

end{
    # update the job
    $null = api put "protectionJobs/$($job.id)" $job
}
