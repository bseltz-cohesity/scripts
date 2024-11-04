$vip = 'mycloudedition'
$username = 'myusername'
$domain = 'mydomain.net'
$vmName = 'mysqlvm'
$vmFqdn = 'mysqlvm.mydomain.net'
$prefix = 'restore-'
$awsSource = '677331782443/MyAwsUser'
$region = 'us-east-2'
$vpc = 'vpc-0775f56292f9ba445'
$subnet = 'subnet-06ec87d3c93438715'
$securityGroup = 'sg-0800ca456835a2dbc'
$instanceType = 't3.medium'
$sourceSQLServer = 'mysqlvm.mydomain.net'
$sourceDBs = 'CohesityDB', 'BigDB'
$mdfFolder = 'c:\sqldata'

# clone VM to AWS
$newIp = ./cloneVmToAws.ps1  -vip $vip `
                             -username $username `
                             -domain $domain `
                             -vmName $vmName `
                             -prefix $prefix `
                             -powerOn `
                             -awsSource $awsSource `
                             -region $region `
                             -vpc $vpc `
                             -subnet $subnet `
                             -securityGroup $securityGroup `
                             -instanceType $instanceType `
                             -wait

# remove unwanted auto-registration
./unregisterPhysical.ps1 -vip $vip `
                         -username $username `
                         -domain $domain `
                         -serverName $newIp

$newVmName = "$($prefix)$($vmName)"
$newFqdn = "$($prefix)$($vmFqdn)"

# add host mapping (to avoid waiting for DNS)
./addCustomHostMapping.ps1 -vip $vip `
                           -username $username `
                           -ip $newIp `
                           -hostNames $newVmName, $newFqdn

# register as physical source
./registerPhysical.ps1 -vip $vip `
                       -username $username `
                       -domain $domain `
                       -serverName $newFqdn

# register as SQL
./registerSQL.ps1 -vip $vip `
                  -username $username `
                  -domain $domain `
                  -server $newFqdn

# restore SQL databases to latest point in time
./restoreSQLDBs.ps1 -vip $vip `
                    -username $username `
                    -domain $domain `
                    -sourceServer $sourceSQLServer `
                    -targetServer $newFqdn `
                    -sourceDBnames $sourceDBs `
                    -overwrite `
                    -latest `
                    -mdfFolder $mdfFolder `
                    -wait -progress
