#!/bin/bash

cd ~/scripts/python

# settings =====================================
vCenter='myvcenter.mydomain.net'
vCenterUser='administrator@vsphere.local'
vms='my-helios-vm1,my-helios-vm2,my-helios-vm3,my-helios-vm4'

heliosEndPoint='myhelios.mydomain.net'
heliosUser='admin'

cluster='mycluster.mydomain.net'
clusterUser='myuser'
pg='myVMprotectionGroup'

logfile='log-heliosVEBackup.txt'
# end settings =================================

echo -e "\n*** $(date) : Script Started" | tee $logfile

# record MAC addresses
echo -e "*** $(date) : Recording MAC Addresses\n" | tee -a $logfile
python3 -u vmMacAddresses.py -vc $vCenter -vu $vCenterUser -vms $vms | tee -a $logfile

# shutdown VMs
echo -e "\n*** $(date) : Shutting Down VMs\n" | tee -a $logfile
python3 -u shutdownVMs.py -vc $vCenter -vu $vCenterUser -vms $vms | tee -a $logfile

# run protection group
echo -e "*** $(date) : Starting Backup\n" | tee -a $logfile
python3 -u backupNow.py -v $cluster -u $clusterUser -j "${pg}" -q -w | tee -a $logfile

# power on VMs
echo -e "\n*** $(date) : Starting VMs\n" | tee -a $logfile
python3 -u powerOnVMs.py -vc $vCenter -vu $vCenterUser -vms $vms | tee -a $logfile

# wait for Helios to be operational
echo -e "\n*** $(date) : Waiting for Helios Startup" | tee -a $logfile
python3 -u heliosMonitor.py -v $heliosEndPoint -u $heliosUser | tee -a $logfile

echo -e "*** $(date) : Script Ended\n" | tee -a $logfile
