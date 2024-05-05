# ScriptUsage: sudo ./driver_installation_test.sh

#!/bin/bash
# This script checks if this VM is eligible for Cohesity-Import by
# checking if requried drivers can be installed on the VM.
#
# For RHEL and CentOS:
# We try to install all the required drivers
# ("xen-blkfront" "xen-netfront" "nvme" "ena") in the $TESTDIR directory using
# function f_try_dummy_drivers_installation.
# We copy directories provided in CopyDirArray and mount directories provided
# in MountDirArray1 and MountDirArray2 into the $TESTDIR and try installing the
# drivers in $TEST_BOOT_DIR by doing chroot on $TESTDIR.
#
# For Ubuntu:
# We try to install all the required drivers ("nvme" "ena") in the $TESTDIR
# directory using function f_try_dummy_drivers_installation, in which we use
# mkinitramfs to create a new initramfs file in the $TESTDIR and provide the
# custom config dir to the command in which we have added the required modules.
#
# For all OS types.
# Then we check if all the necesary drivers
# {(Ubuntu -> "nvme" "ena"), (RHEL, CENTOS -> all four drivers) are installed
# properly in the $TESTDIR or not.
# This doesn't change the image files or any other files of the VM.

TESTDIR="/mnt/cohesity"
TEST_BOOT_DIR=$TESTDIR"/boot"
declare -a MountDirArray1=("proc" "sys" "dev" "run")
declare -a MountDirArray2=("bin" "lib" "lib64")
declare -a EmptyDirArray=("var" "var/tmp")
declare -a CopyDirArray=("boot" "etc" "usr")

#------------------------------------------------------------------------------
# Method to check if the OS type of the guest VM is ubuntu or not.
# Workflow for ubuntu will be different from Rhel/CentOS.
#------------------------------------------------------------------------------
f_is_ubuntu() {
  count=$(grep --only-matching --ignore-case 'ubuntu' /etc/*release | wc -l)

  if [ $count != 0 ]; then
    echo "VM is Ubuntu" | tee --append $LOGFILE
    return $(true)
  fi

  return $(false)
}

#------------------------------------------------------------------------------
# Method to check if the VM is CentOS or not.
# Since some commands are different for CentOS.
#------------------------------------------------------------------------------
f_is_centos(){
  # Check if VM is CentOS or not.
  centos_count=$(grep --only-matching --ignore-case 'CentOS' /etc/*release | wc -l)

  if [[ $centos_count != 0 ]]; then
    # VM is CentOS.
    echo "VM is CentOS" | tee --append $LOGFILE
    return $(true)
  fi

  return $(false)
}

#------------------------------------------------------------------------------
# Method to check if the VM is RHEL or not.
# Since some commands are different for RHEL.
#------------------------------------------------------------------------------
f_is_rhel(){
  # Check if VM is RHEL or not.
  rhel_count=$(grep --only-matching --ignore-case 'Red Hat' /etc/*release | wc -l)

  if [[ $rhel_count != 0 ]]; then
    # VM is RHEL.
    echo "VM is RHEL" | tee --append $LOGFILE
    return $(true)
  fi

  return $(false)
}

#------------------------------------------------------------------------------
# Method to mount the helper directories like /sys, /proc to $TESTDIR.
#------------------------------------------------------------------------------
f_mount_helper_dirs() {
  # Check if the directory exists or already mounted before mounting the
  # device.

  if test -d /proc && ! mount | grep -q $TESTDIR/proc ; then
    sudo mkdir $TESTDIR/proc
    echo "Mounting $TESTDIR/proc ..."
    sudo mount -t proc proc $TESTDIR/proc
  fi

  if test -d /sys && ! mount | grep -q $TESTDIR/sys ; then
    sudo mkdir $TESTDIR/sys
    echo "Mounting $TESTDIR/sys ..."
    sudo mount -t sysfs sys $TESTDIR/sys
  fi

  if test -d /dev && ! mount | grep -q $TESTDIR/dev ; then
    sudo mkdir $TESTDIR/dev
    echo "Mounting $TESTDIR/dev ..."
    sudo mount -o bind /dev $TESTDIR/dev
  fi

  if test -d /run && ! mount | grep -q $TESTDIR/run ; then
      sudo mkdir $TESTDIR/run
      echo "Mounting $TESTDIR/run ..."
      # Using --rbind as argument to avoid the error in RHEL 8.
      sudo mount --rbind /run $TESTDIR/run
  fi

  for dir in ${MountDirArray2[@]}; do
    if test -d /$dir && ! mount | grep -q $TESTDIR/$dir ; then
      sudo mkdir $TESTDIR/$dir
      echo "Mounting $TESTDIR/$dir ..."
      sudo mount -o ro --rbind /$dir $TESTDIR/$dir
    fi
  done
}


#------------------------------------------------------------------------------
# Method to unmount the helper directories like /sys, /proc
# from $TESTDIR.
#------------------------------------------------------------------------------
f_unmount_dir() {
  local directory=$1
   # Check if the unmount has already happened or not.
  if mount | grep -q $TESTDIR/$directory ; then
    echo "Unmounting $TESTDIR/$directory ..."
    umount --recursive $TESTDIR/$directory
    if [ $? -ne 0 ]; then
      echo "NOTE: ERROR IN UNMOUNTING $TESTDIR/$directory, UNMOUNT IT MANUALLY."
      is_failed_to_unmount_dirs=true
    else
      echo "Removing $TESTDIR/$directory ..."
      rm -rf $TESTDIR/$directory
    fi
  fi
}

#------------------------------------------------------------------------------
# Method to unmount the helper directories like /sys, /proc
# and delete the copied directories like /usr, /boot from $TESTDIR.
#------------------------------------------------------------------------------
f_unmount_and_delete_helper_dirs() {
  # Sync, to write data from cache to disk, to perform clean unmount.
  sync; sync

  if f_is_ubuntu; then
    echo "Deleting $TESTDIR/boot ..."
    rm -rf $TESTDIR/boot
    echo "Deleting $TESTDIR/etc ..."
    rm -rf $TESTDIR/etc
    echo "Deleting $TESTDIR ..."
    rm -rf $TESTDIR
    return
  fi

  is_failed_to_unmount_dirs=false

  # Try unmounting all the mounted directories in reverse order.
  for (( idx=${#MountDirArray2[@]}-1 ; idx>=0 ; idx-- )) ; do
    dir="${MountDirArray2[idx]}"
    f_unmount_dir $dir
  done

  for (( idx=${#MountDirArray1[@]}-1 ; idx>=0 ; idx-- )) ; do
    dir="${MountDirArray1[idx]}"
    f_unmount_dir $dir
  done

  # Delete the copied directories in reverse order.
  for (( idx=${#CopyDirArray[@]}-1 ; idx>=0 ; idx-- )) ; do
    dir="${CopyDirArray[idx]}"
    echo "Deleting $TESTDIR/$dir ..."
    rm -rf  $TESTDIR/$dir
  done

  # Delete the created directories in reverse order.
  for (( idx=${#EmptyDirArray[@]}-1 ; idx>=0 ; idx-- )) ; do
    dir="${EmptyDirArray[idx]}"
    echo "Deleting $TESTDIR/$dir ..."
    rm -rf  $TESTDIR/$dir
  done

  if [[ $is_failed_to_unmount_dirs == true ]]; then
    echo "NOTE: REMOVE $TESTDIR MANUALLY AFTER UNMOUNTING REMAINING DIRECTORIES."
  else
    echo "Deleting $TESTDIR ..."
    rm -rf $TESTDIR
  fi
}

#------------------------------------------------------------------------------
# Method to copy and mount the required directories into the $TESTDIR.
#------------------------------------------------------------------------------
f_copy_boot_directory() {
  # Unmount and clean the test dir before starting copying the directory.
  f_unmount_and_delete_helper_dirs

  # Create a test directory.
  echo "Creating empty $TESTDIR ..."
  mkdir -p $TESTDIR

  if f_is_ubuntu; then
    echo "Copying $TESTDIR/etc ..."
    cp -rp /etc $TESTDIR
    echo "Creating empty $TESTDIR/boot ..."
    mkdir $TESTDIR/boot
    return
  fi

  # Mount the helper directories first.
  f_mount_helper_dirs

  # Create the empty dirs.
  for dir in ${EmptyDirArray[@]}; do
    echo "Creating empty $TESTDIR/$dir ..."
    mkdir $TESTDIR/$dir
  done

  # Copy the contents of /boot and /etc to $TESTDIR.
  for dir in ${CopyDirArray[@]}; do
    echo "Copying $TESTDIR/$dir ..."
    cp -rp /$dir $TESTDIR
  done
}

#------------------------------------------------------------------------------
# Method to set the kernel version on the basis of OS type and provided
# image file.
#------------------------------------------------------------------------------
f_set_kernel_version () {
  local image_file_path="$1"
  # Fetch the kernel version of the initramfs file.
  if f_is_ubuntu; then
    # The kernel version from initrd.img-5.4.0-86-generic is 5.4.0-86-generic.
    kernel_version=$(echo $image_file_path | sed -e 's/^\/boot\/initrd.img-//')
  else
    # The kernel version from initramfs-3.10.0-693.el7.x86_64.img is 3.10.0-693.el7.x86_64.
    kernel_version=$(echo $image_file_path | sed -e 's/^\/boot\/initramfs-//' -e 's/.img$//')
  fi
}

#------------------------------------------------------------------------------
# Method to check if drivers in $DriverArray are installed to image file
# provided as $1.
# $failed_drivers_msg will be updated accordingly.
#------------------------------------------------------------------------------
f_check_if_drivers_installed() {
  local image_file_path="$1"

  # Return early if image file is empty or list of drivers is empty.
  if [ "$image_file_path" = "" ]; then
    failed_drivers_msg="$failed_drivers_msg [ Image file is not provided. ] "
    return $(false)
  fi

  if [ ${#DriverArray[@]} -eq 0 ]; then
    failed_drivers_msg="$failed_drivers_msg [ Driver Check list is empty for image file $image_file_path ] "
    return $(false)
  fi

  f_set_kernel_version $image_file_path

  # Add the suffix path $TESTDIR to the image file path as we installed drivers
  # in mocked directory.
  image_file_path=$TESTDIR"/"$image_file_path
  local failed_drivers=""
  # Verify that all drivers are installed or not.
  for driver in ${DriverArray[@]}; do
    if f_is_ubuntu; then
      local driver_count=$(lsinitramfs $image_file_path | grep "$driver.ko")
    else
      local driver_count=$(lsinitrd $image_file_path | grep "$driver.ko")
    fi

    if [[ -z ${driver_count} ]]; then
      # Could not install the driver.
      failed_drivers="$failed_drivers $driver"
    fi
  done

  if test -z "$failed_drivers"; then
    echo "All drivers found successfully for kernel: $kernel_version."
    return $(true)
  else
    failed_drivers_msg="$failed_drivers_msg [ Failed to find drivers: $failed_drivers, for kernel $kernel_version ] "
  fi

  return $(false)
}


#------------------------------------------------------------------------------
# Method to test drivers installation to initramfs for all kernel versions.
#------------------------------------------------------------------------------
f_try_dummy_drivers_installation() {
  # Failed drivers error message.
  failed_drivers_msg=""
  local is_failed_to_install_drivers=false
  # Create a copy of /boot directory and mount the helper directories to try
  # the driver installation.
  f_copy_boot_directory

  if f_is_ubuntu; then
    echo "VM is Ubuntu"

    # List of drivers that needs to be checked if installed properly.
    declare -a DriverArray=("nvme" "ena")
    # Copy the original file.
    local module_file=$TESTDIR"/etc/initramfs-tools/modules"

    # Injecting drivers to initramfs for ubuntu.
    echo "# Injecting Drivers during VM Import from Cohesity." | sudo tee --append $module_file

    # Check if the required drivers are already present in the modules.
    for driver in ${DriverArray[@]}; do
      driver_count=$(cat $module_file | grep --line-regexp "$driver")

      if [[ -z ${driver_count} ]]; then
        echo "Adding $driver for ubuntu to $module_file"
        # Driver is not present in the drivers. Add it.
        echo "$driver" | sudo tee --append $module_file
      fi
    done
    # Fetching the initrd file names to check if drivers are installed or not.
    find /boot -name 'initrd.img-*' | egrep -v '*kdump.img' | egrep -v '*rescue*' > $TESTDIR/files.txt
    while read file; do
      # Regenerate initrd in the $TEST_BOOT_DIR dir.
      f_set_kernel_version $file
      mkinitramfs -k $kernel_version -o $TESTDIR"/"$file -d $TESTDIR"/"etc/initramfs-tools/
      if [ $? -ne 0 ]; then
        echo "Failed to add drivers. Please check if boot disk has sufficient space."
        is_failed_to_install_drivers=true
      elif ! f_check_if_drivers_installed $file; then
        is_failed_to_install_drivers=true
      fi
    done < $TESTDIR/files.txt
  else
    # List of drivers that need to be installed.
    declare -a DriverArray=("xen-blkfront" "xen-netfront" "nvme" "ena")

    # Fetching the initramfs file names.
    sudo chroot $TESTDIR /bin/bash -c "find /boot -name 'initramfs-*.img' | egrep -v '*kdump.img' | egrep -v '*rescue*'" > $TESTDIR/files.txt

    while read file; do
      f_set_kernel_version $image_file_path

      drivers_to_be_added=""
      for driver in ${DriverArray[@]}; do
        driver_count=$(lsinitrd $TESTDIR/${file} | grep "$driver.ko")

        if [[ -z ${driver_count} ]]; then
          # $driver is not present in the drivers.
          drivers_to_be_added="$drivers_to_be_added $driver"
        fi
      done

      if test -z "$drivers_to_be_added"; then
        echo "All drivers are already present for kernel:$kernel_version."
        continue
      else
        echo "Adding $drivers_to_be_added for kernel:$kernel_version into the file $TESTDIR/$file."
        sudo chroot $TESTDIR /bin/bash -c "dracut -f --add-drivers '$drivers_to_be_added' $file $kernel_version"
        if [ $? -ne 0 ]; then
          echo "Dracut has failed to add drivers for kernel version $kernel_version. Please check if boot disk has sufficient space."
          is_failed_to_install_drivers=true
          continue
        fi
      fi

      if ! f_check_if_drivers_installed $file; then
        is_failed_to_install_drivers=true
      fi
    done < $TESTDIR/files.txt
  fi

  if ! [ -s $TESTDIR/files.txt ]; then
    failed_drivers_msg="$failed_drivers_msg, Not able to find the initrd/initramfs image files in $TESTDIR/boot."
    is_failed_to_install_drivers=true
  fi

  if [[ $is_failed_to_install_drivers == true ]]; then
    echo "NOT ABLE TO INSTALL THE DRIVERS ERROR: $failed_drivers_msg"
  else
    echo 'ALL DRIVERS CAN BE INSTALLED SUCCESSFULLY FOR ALL KERNEL VERSIONS.'
  fi

  # Unomount the helper directories and delete the $TESTDIR.
  f_unmount_and_delete_helper_dirs
}

# Attached disk's OS should be either RED HAT, CentOS or UBUNTU.
if ! ( f_is_ubuntu ||  f_is_rhel || f_is_centos ) ; then
    echo "VM should be either RED HAT, CentOS or UBUNTU."
    exit 1
fi

# Check if drivers can be installed properly or not.
f_try_dummy_drivers_installation
