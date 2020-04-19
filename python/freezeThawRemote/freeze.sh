#!/bin/bash
echo "running freeze script" > ./freeze.log
# freeze commands here
nohup ./waitforsnaps.sh 1> waitforsnaps.log 2> /dev/null &
echo "ending freeze script" >> ./freeze.log
