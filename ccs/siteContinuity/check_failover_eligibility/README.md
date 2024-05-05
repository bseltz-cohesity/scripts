# Drivers installation test script for RHEL/CentOS/Ubuntu failover from vCenter to AWS

## Overview

Cohesity install some drivers(ena, nvme, xen-blkfront, xen-netfornt) during the
failover of a VM from vCenter to AWS to the target VM.

This script tests whether these drivers can be installed or not.
This script mimics the root directory at /mnt/cohesity for which it mount some
directories like /proc, /sys etc. and copies some directories like /boot, /etc
and /usr (See the script for details.) 

### Prerequisites

* VM should be either RHEL, CentOS, Ubuntu.
* UEFI VMs are not supported.
* All the drivers should be present in the VM, this script don't download
  drivers, it only tries to install them.
* There should be enough empty space in the VM to copy the requried
  directories.
* Script should be run with sudo.
* It will create a directory /mnt/cohesity. This should not be already present. 

### Run script

* The script will print some logs.

* It will print "ALL DRIVERS CAN BE INSTALLED SUCCESSFULLY FOR ALL KERNEL
  VERSIONS." if test is successful otherewise it will print "NOT ABLE TO
  INSTALL THE DRIVERS" followed by error message.

* /mnt/cohesity directory should be deleted once it finishes, if it still
  exists then you may have to manually unmount the mounted directories and then
  delete it.

* Run the script using

  ```
  sudo ./drivers_installation_test.sh
  ```

### Have any question

Send me an email at <support@cohesity.com>
