#!/bin/bash

ce_ip='10.0.1.6'
ce_user='admin'
ce_domain='local'
node_1='BSeltz-AzureCE-1'
node_2='BSeltz-AzureCE-2'
node_3='BSeltz-AzureCE-3'
key='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
subscription='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
tenant='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
resgroup='resgroup1'
onprem_ip='192.168.1.198'
onprem_user='admin'
onprem_domain='local'
scriptpath='/Users/myusername/scripts/python'

function f_start_cohesity() {
    python ${scriptpath}/powerCycleAzure.py -s "${ce_ip}" \
                                            -u "${ce_user}" \
                                            -d "${ce_domain}" \
                                            -o poweron \
                                            -n "${node_1}" \
                                            -n "${node_2}" \
                                            -n "${node_3}" \
                                            -k "${key}" \
                                            -t "${tenant}" \
                                            -b "${subscription}" \
                                            -r "${resgroup}" 
}

function f_stop_cohesity() {
    while true; do
        python ${scriptpath}/waitForJob.py -v "${onprem_ip}" -u "${onprem_user}" -d "${onprem_domain}"
        if [ $? -eq 0 ]; then
            break
        fi
        sleep 5
    done
    python ${scriptpath}/powerCycleAzure.py -s "${ce_ip}" \
                                            -u "${ce_user}" \
                                            -d "${ce_domain}" \
                                            -o poweroff \
                                            -n "${node_1}" \
                                            -n "${node_2}" \
                                            -n "${node_3}" \
                                            -k "${key}" \
                                            -t "${tenant}" \
                                            -b "${subscription}" \
                                            -r "${resgroup}" 
}

function f_store_passwords(){
    echo ""
    echo "Please provide secretkey for Azure"
    python ${scriptpath}/storePassword.py -v "azure" -u "${key}"
    echo ""
    echo "Please provide password for Cloud Edition user (${ce_user})"
    python ${scriptpath}/storePassword.py -v "${ce_ip}" -u "${ce_user}" -d "${ce_domain}"
    echo ""
    echo "Please provide password for on-prem user (${onprem_user})"
    python ${scriptpath}/storePassword.py -v "${onprem_ip}" -u "${onprem_user}" -d "${onprem_domain}"
}

function f_show() {
    echo ""
    echo "=== Azure Control Configuration ========"
    echo ""
    echo "scriptpath: ${scriptpath}"
    echo ""
    echo "onprem_ip: ${onprem_ip}"
    echo "onprem_user: ${onprem_user}"
    echo "onprem_domain: ${onprem_domain}"
    echo ""
    echo "ce_ip: ${ce_ip}"
    echo "ce_user: ${ce_user}"
    echo "ce_domain: ${ce_domain}"
    echo ""
    echo "node_1: ${node_1}"
    echo "node_2: ${node_2}"
    echo "node_3: ${node_3}"
    echo ""
    echo "key: ${key}"
    echo "tenant: ${tenant}"
    echo "subscription: ${subscription}"
    echo "resgroup: ${resgroup}"
    echo ""
    echo "======================================="
    echo ""
}

case $1 in
    start)
        f_start_cohesity
        ;;
    stop)
        f_stop_cohesity
        ;;
    show_config)
        f_show
        ;;
    store_passwords)
        f_store_passwords
        ;;
    *)
        echo "usage: ./azure_control.sh [ start | stop | store_passwords | show_config ]"
        ;;
esac