#!/bin/bash
umount /mnt/root_snap
lvremove /dev/mapper/centos-root_snap -y
