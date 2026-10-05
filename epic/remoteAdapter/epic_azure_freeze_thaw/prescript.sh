#!/bin/bash
# unmount previous lv
sudo umount /mydata
sudo vgchange -an myvg
# mount new lv
sudo vgchange -ay myvg
sudo mount /dev/mapper/myvg-mydata /mydata/
