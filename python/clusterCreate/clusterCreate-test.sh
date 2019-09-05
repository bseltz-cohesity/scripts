#!/bin/bash
./clusterCreate.py -s 10.5.64.28 \
                   -u admin \
                   -n 181140263392576 \
                   -n 181140263392540 \
                   -n 181140263384072 \
                   -n 181140263382092 \
                   -v 10.5.64.32 \
                   -v 10.5.64.33 \
                   -v 10.5.64.34 \
                   -v 10.5.64.35 \
                   -c mycluster \
                   -ntp pool.ntp.org \
                   -dns 10.5.64.6 \
                   -dns 10.5.64.7 \
                   -e \
                   -f \
                   -cd mydomain.net \
                   -gw 10.5.64.1 \
                   -m 255.255.254.0 \
                   -igw 10.5.64.1 \
                   -im 255.255.254.0 \
                   -iu admin \
                   -ip admin \
                   -k XXXX-XXXX-XXXX-XXXX



