./clusterCreateVE.ps1 -ip 10.19.0.201 `
                      -netmask 255.255.240.0 `
                      -gateway 10.19.0.1 `
                      -dnsServers 10.19.0.45 `
                      -ntpServers pool.ntp.org `
                      -clusterName SELAB6 `
                      -clusterDomain sa.corp.cohesity.com
