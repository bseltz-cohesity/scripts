#!/bin/bash
lvcreate -s -n root_snap -l 100%FREE /dev/mapper/centos-root
mkdir /mnt/root_snap
mount -t xfs -o nouuid /dev/mapper/centos-root_snap /mnt/root_snap
