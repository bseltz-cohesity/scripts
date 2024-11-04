#!/bin/bash

sudo mount -t nfs -o soft,intr,noatime,retrans=1000,timeo=900,retry=5,rsize=1048576,wsize=1048576,nolock mycohesity:/myview /mnt/myview/

rsync -rltov /some/data/thisfolder /mnt/myview --delete
rsync -rltov /other/data/thatfolder /mnt/myview --delete

sudo umount /mnt/myview/
