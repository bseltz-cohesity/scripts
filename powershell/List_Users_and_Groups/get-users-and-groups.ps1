# script to list users and groups on a Cohesity cluster
# call this script with two arguments
# clustername / IP
# username for login

# set the first variable to be the cluster name
$CLUSTER = $args[0]
$CLUSTER_USER = $args[1]

### source the cohesity-api helper code
. ./cohesity-api

# set the security to TLS12
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

### authenticate
apiauth -vip $CLUSTER -username $CLUSTER_USER

$users = api get users

# create an array to store our results 


$list = for ( $i = 0; $i -lt $users.Length; $i++) {
    [PSCustomObject] @{
        ObjectName = $users[$i].username
        ObjectType = "User"
        Domain = $users[$i].domain
        Created = (msecsToDate($users[$i].createdTimeMsecs))
        Modified = (msecsToDate($users[$i].lastUpdatedTimeMsecs))
        Email = $users[$i].emailAddress
        roles = $users[$i].roles -join ','
        }
}

$groups = api get groups
$list += for ( $i = 0; $i -lt $groups.Length; $i++) {
    [PSCustomObject] @{
        ObjectName = $groups[$i].name
        ObjectType = "Group"
        Domain = $groups[$i].domain
        Created = (msecsToDate($groups[$i].createdTimeMsecs))
        Modified = (msecsToDate($groups[$i].lastUpdatedTimeMsecs))
        Email = "-"
        roles = $groups[$i].roles -join ','
        }
}

echo $list
