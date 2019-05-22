#!/usr/bin/bash

function f_start_cohesity() {
  /home/cohesity/software/bin/cohesity_aws_setup start_cluster --cohesity_aws_params_file=/home/cohesity/data/aws/cluster_config_params.json
}

function f_stop_cohesity() {
 /home/cohesity/software/bin/cohesity_aws_setup stop_cluster --cohesity_aws_params_file=/home/cohesity/data/aws/cluster_config_params.json
}

case $1 in
  start)
    f_start_cohesity
    ;;
  stop)
    f_stop_cohesity
    ;;
  *)
    echo "Invalid operation"
    ;;
esac
