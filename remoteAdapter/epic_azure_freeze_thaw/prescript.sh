#!/bin/bash
# unmount previous disks
sudo umount /data/snapdisk1
sudo umount /data/snapdisk2
sudo umount /data/snapdisk3
# mount new disks
sudo mount -o nouuid -t xfs /dev/$(ls -l /dev/disk/azure/scsi1 | grep 'lun4-part1 ' | cut -d' ' -f12 | cut -d'/' -f4) /data/snapdisk1
sudo mount -o nouuid -t xfs /dev/$(ls -l /dev/disk/azure/scsi1 | grep 'lun5-part1 ' | cut -d' ' -f12 | cut -d'/' -f4) /data/snapdisk2
sudo mount -o nouuid -t xfs /dev/$(ls -l /dev/disk/azure/scsi1 | grep 'lun6-part1 ' | cut -d' ' -f12 | cut -d'/' -f4) /data/snapdisk3
