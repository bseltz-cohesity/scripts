#!/bin/bash

ce_ip='172.31.28.144'
ce_user='admin'
ce_domain='local'
node_1='i-00b359f39aa83551d'
node_2='i-0aa0725c31c208d63'
node_3='i-0fcc7118fb230b47e'
key='XXXXXXXXXXXXXXXXXXXX'
region='us-east-2'
onprem_ip='192.168.1.198'
onprem_user='admin'
onprem_domain='local'
scriptpath='/Users/myusername/scripts/python'

function f_start_cohesity() {
    python ${scriptpath}/powerCycleAWS.py -s "${ce_ip}" \
                                          -u "${ce_user}" \
                                          -d "${ce_domain}" \
                                          -o poweron \
                                          -n "${node_1}" \
                                          -n "${node_2}" \
                                          -n "${node_3}" \
                                          -k "${key}" \
                                          -r "${region}" 
}

function f_stop_cohesity() {
    while true; do
        python ${scriptpath}/waitForJob.py -v "${onprem_ip}" -u "${onprem_user}" -d "${onprem_domain}"
        if [ $? -eq 0 ]; then
            break
        fi
        sleep 5
    done
    python ${scriptpath}/powerCycleAWS.py -s "${ce_ip}" \
                                          -u "${ce_user}" \
                                          -d "${ce_domain}" \
                                          -o poweroff \
                                          -n "${node_1}" \
                                          -n "${node_2}" \
                                          -n "${node_3}" \
                                          -k "${key}" \
                                          -r "${region}" 
}

function f_store_passwords(){
    echo ""
    echo "Please provide secretkey for AWS"
    python ${scriptpath}/storePassword.py -v "ec2" -u "${key}"
    echo ""
    echo "Please provide password for Cloud Edition user (${ce_user})"
    python ${scriptpath}/storePassword.py -v "${ce_ip}" -u "${ce_user}" -d "${ce_domain}"
    echo ""
    echo "Please provide password for on-prem user (${onprem_user})"
    python ${scriptpath}/storePassword.py -v "${onprem_ip}" -u "${onprem_user}" -d "${onprem_domain}"
}

function f_show() {
    echo ""
    echo "=== AWS Control Configuration ========"
    echo ""
    echo "scriptpath: ${scriptpath}"
    echo ""
    echo "onprem_ip: ${onprem_ip}"
    echo "onprem_user: ${onprem_user}"
    echo "onprem_domain: ${onprem_domain}"
    echo "onprem_job: ${onprem_job}"
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
    echo "region: ${region}"
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