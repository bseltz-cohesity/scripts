####ScriptUsage: ./Unity_Pre_Post_Script.sh <Pre/Post> <Unity_Filsystem_CLIID> <UNITY_SNAPSHOT_NAME>####

#!/bin/sh
set -e
### INPUT PARAMS
MODE=$1
UNITY_FILESYSTEM_CLI_ID=$2
UNITY_SNAPSHOT_NAME=$3


### UNITY COMMANDS
#Example : uemcli /prot/snap -source res_1 show
UNITY_SNAPSHOT_LIST_COMMAND="uemcli -u admin /prot/snap -source "
#Example : uemcli /prot/snap create -async -source res_1 -name cohesity_snap1 -access share -keepFor 1d
UNITY_SNAPSHOT_COMMAND="uemcli -u admin /prot/snap create -async -source "
#Example : uemcli -u admin -securepassword /prot/snap -name cohesity_snap_1 delete -force
UNITY_SNAPSHOT_DELETE_COMMAND="uemcli -u admin /prot/snap -name "
#Example : uemcli /stor/prov/fs show |grep -i $UNITY_FILESYSTEM_CLI_ID
UNITY_FILESYSTEM_LIST_COMMAND="uemcli -u admin -sslpolicy store /stor/prov/fs -id "


### Validate the FilesystemID input value
### If input value of Filesystem ID does not exist then exit the script

ValidateInputFilesystemID(){
      set +e

      echo "Validating the source Filesystem ID..."
      cmd=$UNITY_FILESYSTEM_LIST_COMMAND$UNITY_FILESYSTEM_CLI_ID" show"
      output=`$cmd`
      status=$?
        if [ "$status" -eq 0 ]; then
                echo "***** Filesystem ID $UNITY_FILESYSTEM_CLI_ID Found *****" 
        else
                echo "Invalid Filesystem ID $UNITY_FILESYSTEM_CLI_ID! Enter Valid Filesystem CLI ID!"
                exit 1
        fi
}

### Create the Snapshot of the Volume.

CreateSnapshot(){
        echo "***** Creating snapshot: $UNITY_SNAPSHOT_NAME *****"
        cmd=$UNITY_SNAPSHOT_COMMAND$UNITY_FILESYSTEM_CLI_ID" -name "$UNITY_SNAPSHOT_NAME" -access share -keepFor 10d"
        status=$($cmd)
        sleep 5s
}


### Deletes a specific Snapshot.
DeleteSnapshot(){
        echo "***** Deleting snapshot: $UNITY_SNAPSHOT_NAME *****"
        cmd=$UNITY_SNAPSHOT_DELETE_COMMAND$UNITY_SNAPSHOT_NAME" delete -force"
        status=$($cmd)
        sleep 3s
}


### Run commands to fetch the snapshot ID and protocol  
### Then create the snapshot Share 

CreateSnapshotShare(){
set +e
echo "***** Creating Snapshot Share *****"
SNAPSHOT_ID=`uemcli -u admin /prot/snap -name $UNITY_SNAPSHOT_NAME show | grep -i ID | awk '{print $4}'`
PROTOCOL=`uemcli -u admin /stor/prov/fs -id $UNITY_FILESYSTEM_CLI_ID show |grep -i Protocol |awk '{print $3}'`
UNITY_SNAPSHOT_SHARE_CREATE="uemcli -u admin /prot/snap/$PROTOCOL create -name "
#CREATEHOSTENTRY=`uemcli -u admin -p Unity123! /remote/host create -name CohesitySubnet -type subnet -addr $COHESITY_ADDR -netmask $COHESITY_NETMASK`  
if [[ $PROTOCOL == nfs ]]; then
      NFScmd=$UNITY_SNAPSHOT_SHARE_CREATE$UNITY_SNAPSHOT_NAME"_NFSShare -snap "$SNAPSHOT_ID" -path / -defAccess root"
      output=`$NFScmd`
      status=$?
        if [ "$status" -eq 0 ]; then
                echo "***** NFS Snapshot Share for $UNITY_SNAPSHOT_NAME Created Successfully *****" 
        else
                echo "***** NFS Snapshot Share for $UNITY_SNAPSHOT_NAME Creation Failed *****"
                exit 1
        fi

else
      CIFScmd=$UNITY_SNAPSHOT_SHARE_CREATE$UNITY_SNAPSHOT_NAME"_CIFSShare -snap "$SNAPSHOT_ID" -path /"
      output=`$CIFScmd`
      status=$?
        if [ "$status" -eq 0 ]; then
            echo "***** CIFS Snapshot Share for $UNITY_SNAPSHOT_NAME Created Successfully *****" 
        else
            echo "***** CIFS Snapshot Share for $UNITY_SNAPSHOT_NAME Creation Failed *****"
            exit 1
        fi
fi

}


### Runs the Command & Fetch the list of all the snapshots
### Then grep the Snapshot name to confirm if the snapshot exists or not
### return value 0 if present. 1 if not present

FetchSnapshotList(){
        set +e

        cmd=$UNITY_SNAPSHOT_LIST_COMMAND$UNITY_FILESYSTEM_CLI_ID" show"
        status=$($cmd)
        if [[ $status == *$UNITY_SNAPSHOT_NAME* ]]; then
                retval=0
        else
                retval=1
        fi
        return "$retval"
}



### Pre check before a snapshot is created.
### If Snapshot with the same name is present - DeleteSnapshot is called.
PrecheckifSnapshotExists(){
        FetchSnapshotList
        status=$?
        if [ "$status" -eq 0 ]; then
                echo "***** Precheck: snapshot $UNITY_SNAPSHOT_NAME found *****"
                DeleteSnapshot
        else
                echo "***** Precheck: snapshot $UNITY_SNAPSHOT_NAME not found *****"
        fi
}

### Post check to validate if the snapshot is created.
### If the snapshot with the same name is not present code exit with error code 1.
PostcheckifSnapshotExists(){
        FetchSnapshotList
        status=$?
        if [ "$status" -eq 1 ]; then
                echo "***** Prescript Final Validation: snapshot $UNITY_SNAPSHOT_NAME not found *****"
                exit 1
        else
                echo "***** Prescript Final Validation: snapshot $UNITY_SNAPSHOT_NAME found *****"

        fi
}

### In the Post Script call, Final check to confirm the DeleteSnapshot was successful
### If the snapshot with the same name is present code exit with error code 1.
PostScriptFinalValidation(){
        FetchSnapshotList
        status=$?
        if [ "$status" -eq 1 ]; then
                echo "***** Post Final Validation: snapshot $UNITY_SNAPSHOT_NAME not found *****"
        else
                echo "***** Post Final Validation: snapshot $UNITY_SNAPSHOT_NAME found *****"
                exit 1

        fi

}


### MAIN

if [ $# -eq 3 ]
  then
    echo "****** Executing Unity Pre and Post Script ******"

    if [ "$MODE" == "pre"  ] ; then
        ValidateInputFilesystemID
        PrecheckifSnapshotExists
        CreateSnapshot
        PostcheckifSnapshotExists
        CreateSnapshotShare
elif [ "$MODE" == "post"  ] ; then
        PrecheckifSnapshotExists
        PostScriptFinalValidation
else
        echo "Invalid Mode:$MODE. Valid values pre/post"
        exit 1
fi
else 
    echo "ENTER CORRECT INPUTS!"
    echo "ScriptUsage: <ScriptName> <pre/post> <UNITY_FILESYSTEM_CLI_ID> <SnapshotName>####"
    exit 1
fi