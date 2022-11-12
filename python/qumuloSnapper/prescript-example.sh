#!/bin/bash

COHESITY_CLUSTER=mycluster.mydomain.net
COHESITY_USER=mydomain.net\\nasuser
COHESITY_PROTECTION_GROUP=QumuloBackup
QUMULO=qumulo1
QUMULO_USER=quser
SMB_USER=mydomain.net\\nasuser
python ./qumuloSnap.py -v $COHESITY_CLUSTER \
                       -u $COHESITY_USER \
                       -q $QUMULO \
                       -qu $QUMULO_USER \
                       -j $COHESITY_PROTECTION_GROUP \
                       -su $SMB_USER

python ./backupNow.py -v $COHESITY_CLUSTER \
                      -u $COHESITY_USER \
                      -j $COHESITY_PROTECTION_GROUP \
                      -x
