#!/usr/bin/env python3
"""Certificate Improvement"""

import time
import requests
import sys
import os
import json
import urllib3
import shutil
# import pyhesity wrapper module
from pyhesity import *

### ignore unsigned certificates
import requests.packages.urllib3

import logging

### command line arguments
import argparse
parser = argparse.ArgumentParser()

parser.add_argument('-c', '--cluster', type=str, default=None)

parser.add_argument('--dr', action='store_true', help='Disaster Recovery')

args = parser.parse_args()

clusterfile = args.cluster

disaster_recovery = args.dr

requests.packages.urllib3.disable_warnings()

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Configure the logging settings
log_file_path = "cert.log"  # Set the path to the log file
log_level = logging.DEBUG  # Set the desired log level

# Create a logger
logger = logging.getLogger("cert")
logger.setLevel(log_level)

# Create a file handler and set the log level
file_handler = logging.FileHandler(log_file_path)
file_handler.setLevel(log_level)

# Create a console handler and set the log level
console_handler = logging.StreamHandler()
console_handler.setLevel(log_level)

# Create a formatter and set it for both handlers
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
file_handler.setFormatter(formatter)
console_handler.setFormatter(formatter)

# Add the handlers to the logger
logger.addHandler(file_handler)
logger.addHandler(console_handler)


def get_cluster_version(ip):
    """Function to get cluster software version

    Args:
        cluster_detail (Dict): Cluster detail with IP, Username, Password

    Returns:
        Dict | None: Returns information about Cohesity Cluster
    """

    # Supported release version for cert improvement
    supported_version = '6.8.1_u5_release'

    try:
        # Send an HTTP GET request with the cookies
        response = api('get', '/public/cluster')

        software_version = response['clusterSoftwareVersion'].split("-")[0]
        if software_version < supported_version:
            logger.error(f"Cluster " + ip + " is not a Supported version")
            return None
        logger.info(f"Cluster "+ip+" is a supported version")
        return response

    except requests.exceptions.RequestException as e:
        logger.error(f"An error occurred: {e}")


def ca_keys():
    """ Function to get Cohesity CA keys from cluster

    Returns:
        String: PrivateKey, Certificate
    """

    try:
        # Send an HTTP GET request for ca-keys
        response = api('get', 'cert-manager/ca-keys', v=2)

        if response is not None:
            logger.info("Fetched Cohesity CA keys from Cluster")
            return response['privateKey'], response['caChain']
        else:
            logger.error(f"ca-keys request failed!")
            exit(1)

    except requests.exceptions.RequestException as e:
        logger.error(f"An error occurred: {e}")
        exit(1)


def bootstrap_targets(target_list, cert, privateKey, \
    setflag=None, dr=False, ip='', bootstrapped_ip=[]):
    """ Function to bootstrap cohesity CA keys to target clusters

    Args:
        target_list (List): List of Target Clusters
        cert (Srting): Primary Cluster Certificate
        privateKey (String): Primary Cluster PrivateKey
    """
    if not dr:
        bootstrap = input("Continue bootstrapping clusters (Y/N)? ").strip().lower()
        if bootstrap != "y" and bootstrap != "yes":
            logger.info("Skipping cluster bootstrap!!")

    for target in target_list:
        if target['ip'] in bootstrapped_ip:
            logger.info("Cluster %s already bootstrapped !"% target['ip'])
            continue
        target_mfa = None
        target_password = None

        logger.info("Bootstrapping started on Cluster from "+ target['ip'])

        target_password = target.get('password')
        target_mfa = target.get('mfaCode')
        apiauth(vip=target['ip'], username=target['username'], password=target_password, mfaCode=target_mfa)

        if apiconnected() is False:
            logger.error('authentication failed for Cluster %s'+ target['ip'])
            continue

        cluster_version = get_cluster_version(target['ip'])

        if cluster_version is None:
            logger.error("Target Cluster %s is not in supported version"+ target['ip'])
            logger.error("Skipping bootstrapping on Cluster IP "+ target['ip'])
            continue


        data = {"privateKey":privateKey, "caChain":cert}
        try:

            # Send an HTTP GET request with the cookies
            response = api('post', 'cert-manager/bootstrap-ca' ,data=data, v=2)
            time.sleep(60)
            if response != None:
                time.sleep(120)
                status = ca_status(target['ip'], cert)
                if setflag:
                    set_gflag(target['ip'])
                if status is not None and dr:
                    update_status(ip, target['ip'])
            else:
                logger.error(f"Bootstrap request failed! Error: {response}")

        except requests.exceptions.RequestException as e:
            logger.error(f"An error occurred on bootstrap: {e}")


def ca_status(ip, cert):
    """ Function to check Cluster CA status

    Args:
        target (Dict): Target Cluster details
        cert (String): Target Cluster certificate
    """

    try:
        # Send an HTTP GET request with the cookies
        response = api('get', 'cert-manager/ca-status', v=2)
        if response != None:
            target_cert = response.get('caCertChain')
            if target_cert == cert:
                logger.info("Bootstrap is successfull on Cluster "+ ip)
                return "Success"
            else:
                logger.error("Bootstrap failed on Cluster "+ ip)
        else:
            logger.error(f"Cohesity CA-status request failed!")

    except requests.exceptions.RequestException as e:
            logger.error(f"An error occurred: {e}")


def set_gflag(ip):
    """Function to update gflag on cluster

    Args:
        target (Dict): Target Cluster details
        session_value (String): Session Value
    """

    gflag = {
        'serviceName': "kMagneto",
        'gflags': [
            {
                'name': "magneto_skip_cert_upgrade_for_multi_cluster_registration",
                'value': "false",
                'reason': "Enable agent certificate update"
            }
        ],
        "effectiveNow": True
    }
    gflag_json = json.dumps(gflag)

    url = 'https://'+ip+'/irisservices/api/v1/clusters/gflag'

    try:
        # Send an HTTP GET request with the cookies
        context = getContext()
        response = requests.put(url, verify=False, headers=context['HEADER'], data=gflag_json, cookies=context['COOKIES'])
        if response.status_code == 200:
            logger.info("Successfully updated gflag on Cluster "+ ip)
        else:
            logger.error(f"Updating gflag request failed with status code: {response.status_code} {response.json()} {ip}")

    except requests.exceptions.RequestException as e:
            logger.error(f"An error occurred: {e}")


def get_cluster_file(clusterfile):
    """ Function to get cluster details file

    Returns:
        dict: Primary and Target Clusters
    """


    # Get the absolute path of the cluster file
    cluster_file_path = os.path.abspath(clusterfile)
    logger.info("Cluster details found at "+ cluster_file_path)

    try:
        # Open the JSON file for reading
        with open(cluster_file_path, 'r') as json_file:
            # Load the JSON data into a Python dictionary
            cluster_data = json.load(json_file)
            return cluster_data
    except FileNotFoundError:
        logger.error(f"File '{cluster_file_path}' not found.")
        exit(1)
    except json.JSONDecodeError as e:
        logger.error(f"Error decoding JSON: {e}")
        exit(1)

def authenticate(cluster_list, keys):
    """ function to authenticate and just cluster version

    Args:
        cluster_list (List): Source and Target cluster list

    Returns:
        List: Cluster Keys list
    """

    for each_ip in cluster_list:
        private_key = ""
        cert = ""
        cluster_pw = each_ip.get('password')
        cluster_mfa = each_ip.get('mfaCode')
        logger.info('Authenticating cluster %s', each_ip['ip'])

        #authenticate
        apiauth(vip=each_ip['ip'], username=each_ip['username'], password=cluster_pw, mfaCode=cluster_mfa)
        # exit if not authenticated
        if apiconnected() is False:
            logger.error('authentication failed on %s'+ each_ip['ip'])
            exit(1)

        cluster_version = get_cluster_version(each_ip['ip'])

        if cluster_version is None:
            # exit if not supported version
            logger.error(f"Cluster {each_ip['ip']} is not in supported version")
            exit(1)

        if len(keys) == 0:
            private_key, cert = ca_keys()
            keys[each_ip['ip']] = {"private_key":private_key, "cert":cert}

    return keys

def get_keys_file(cluster_details):
    """ Function to read cluster keys

    Returns:
        Dict: Keys data, Bootstrapped cluster data
    """

    data = {'sources':{}, 'targets':{}}
    status = {}

    # Get the path to the home directory and folder name
    home_dir = os.path.expanduser("~")
    folder_name = ".keys"

    # Combine the home directory and folder name to create the full folder path
    folder_path = os.path.join(home_dir, folder_name)

    # Check if the folder exists
    if os.path.exists(folder_path) and os.path.isdir(folder_path):
        keys_file = "keys.json"

        # Combine the folder path and JSON file name to create the full JSON file path
        keys_file_path = os.path.join(folder_path, keys_file)

        if os.path.exists(keys_file_path):
            # Read and parse the JSON file
            with open(keys_file_path, 'r') as json_file:
                data = json.load(json_file)
        else:
            logger.warning(f"The JSON file '{keys_file}' does not exist in the folder.")

        status_file = "bootstrapped_status.json"
        # Combine the folder path and status file name to create the full JSON file path
        status_file_path = os.path.join(folder_path, status_file)

        if os.path.exists(status_file_path):
            # Read and parse the JSON file
            with open(status_file_path, 'r') as json_file:
                status = json.load(json_file)
        else:
            logger.warning(f"The JSON file '{status_file}' does not exist in the folder.")

    else:
        logger.warning(f"The folder '{folder_name}' does not exist.")


    cluster_source = [ip['ip'] for ip in cluster_details['sources']]
    cluster_target = [ip['ip'] for ip in cluster_details['targets']]

    # verify if keys.json and cluster.json source IP matches
    if (len(list(data['sources'].keys())) > 0 and list(data['sources'].keys()) != cluster_source) \
        or (len(list(data['targets'].keys())) > 0 and list(data['targets'].keys()) != cluster_target):
        logger.error("IP on keys.json and Cluster.json do not match!"+
            " Remove .keys folder manually to start fresh bootstrap.")
        exit(1)

    return data, status


def write_keys(keys):
    """ Write Cluster keys to JSON

    Args:
        keys (Dict): Cluster Keys
    """

    # Specify the folder and file names
    folder_name = ".keys"
    json_file_name = "keys.json"

    # Get the path to the home directory
    home_dir = os.path.expanduser("~")

    # Create the full folder path and JSON file path
    folder_path = os.path.join(home_dir, folder_name)
    json_file_path = os.path.join(folder_path, json_file_name)

    try:
        # Check if the folder exists, and create it if it doesn't
        if not os.path.exists(folder_path):
            os.makedirs(folder_path)
            logger.info(f"Folder '{folder_name}' created in the home directory.")
    except Exception as ex:
        logger.error(f"Error while creating {folder_name} directory! Error: {ex}")
        exit(1)

    try:
        # Write the data to the JSON file
        with open(json_file_path, 'w') as json_file:
            json.dump(keys, json_file, indent=4)
    except Exception as ex:
        logger.error(f"Error while writing {folder_name} directory! Error: {ex}")
        exit(1)

    logger.info(f"Cluster Keys written to '{json_file_name}' file!")

def update_status(source_ip, target_ip):
    """ Function to update bootstrapped status

    Args:
        source_ip (String): Source IP
        target_ip (String): Target IP
    """

    existing_data ={}
    directory_name = ".keys"
    file_name = "bootstrapped_status.json"

    # Get the path to the home directory
    home_dir = os.path.expanduser("~")

    # Create the full directory path and JSON file path
    directory_path = os.path.join(home_dir, directory_name)
    file_path = os.path.join(directory_path, file_name)

    # Create the directory if it doesn't exist
    if not os.path.exists(directory_path):
        os.makedirs(directory_path)
        logger.info(f"Directory '{directory_name}' created")

    # Initialize an empty list for the specific key
    if os.path.exists(file_path):
        with open(file_path, 'r') as json_file:
            existing_data = json.load(json_file)

    if source_ip in existing_data:
        existing_data[source_ip].append(target_ip)
    else:
        existing_data[source_ip] = [target_ip]

    # Write the data to the JSON file
    with open(file_path, 'w') as json_file:
        json.dump(existing_data, json_file, indent=4)

    logger.info(f"Data written to '{file_name}' in '{directory_name}'")

def cluster_recovery(cluster_details):
    """Function to bootstrap source and target clusters

    Args:
        cluster_details (Dict): List of Source and Target Clusters
    """

    keys = {'sources':{}, 'targets':{}}
    bootstrap = input("Start bootstrapping clusters (Y/N)? ").strip().lower()
    if bootstrap != "y" and bootstrap != "yes":
        logger.info("Skipping cluster bootstrap!!")
        exit(1)

    if isinstance(cluster_details.get('sources'), list) and isinstance(cluster_details.get('targets'), list):
        if len(cluster_details.get('sources')) <= 10 and len(cluster_details.get('targets')) <= 10:
            keys, status = get_keys_file(cluster_details)

            keys['sources'] = (authenticate(cluster_details.get('sources'), keys['sources']))
            keys['targets'] = (authenticate(cluster_details.get('targets'), keys['targets']))

            write_keys(keys)

            # bootstrap source to target clusters
            for each_source in keys['sources']:
                boostraped_ip_list = [] if status.get(each_source) is None \
                    else status.get(each_source)
                bootstrap_targets(cluster_details.get('targets'), \
                        keys['sources'][each_source]['cert'], \
                            keys['sources'][each_source]['private_key'], dr=True, \
                                ip=each_source, \
                                    bootstrapped_ip=boostraped_ip_list)
            # bootstrap target to source clusters
            for each_target in keys['targets']:
                boostraped_ip_list = [] if status.get(each_target) is None \
                    else status.get(each_target)
                bootstrap_targets(cluster_details.get('sources'), \
                        keys['targets'][each_target]['cert'], \
                            keys['targets'][each_target]['private_key'], dr=True,\
                                ip=each_target,\
                                    bootstrapped_ip=boostraped_ip_list)
        else:
            logger.error("Bootstrap limit exceeded! Source and Target cannot exceed more than 10!")
            exit(1)
    else:
        logger.error("Invalid JSON Format! Please provide Sources and Targets as list")
        exit(1)

def verify_dr_bootstrap(cluster_details):

    source_bootstrap_status = False
    target_bootstrap_status = False

    directory_name = ".keys"
    file_name = "bootstrapped_status.json"

    bootstrapped_clusters = {}
    # Get the path to the home directory
    home_dir = os.path.expanduser("~")

    # Create the full directory path and JSON file path
    directory_path = os.path.join(home_dir, directory_name)
    file_path = os.path.join(directory_path, file_name)

    # Read JSON file
    if os.path.exists(file_path):
        with open(file_path, 'r') as json_file:
            bootstrapped_clusters = json.load(json_file)
    
    # verify if all targets are bootstrapped
    for source in cluster_details['sources']:
        for target in cluster_details['targets']:
            if bootstrapped_clusters.get(source['ip']) is not None and target['ip'] in bootstrapped_clusters.get(source['ip']):
                source_bootstrap_status = True
            else:
                source_bootstrap_status = False
                break


    # verify if all sources are bootstrapped
    for source in cluster_details['targets']:
        for target in cluster_details['sources']:
            if bootstrapped_clusters.get(source['ip']) is not None and target['ip'] in bootstrapped_clusters.get(source['ip']):
                target_bootstrap_status = True
            else:
                target_bootstrap_status = False
                break

    if source_bootstrap_status and target_bootstrap_status:

        logger.info(f"Bootstrapping is successful on all clusters!")
        # Check if the directory exists and remove it if it does
        if os.path.exists(directory_path) and os.path.isdir(directory_path):
            try:
                shutil.rmtree(directory_path)
                logger.info(f"Directory '{directory_name}' removed successfully.")
            except OSError as e:
                logger.error(f"Error removing directory: {e}")
        else:
            logger.error(f"Directory '{directory_name}' does not exist.")

def main():
    """
    Entry point to Certificate improvement
    """

    if clusterfile is None:
        print("Usage: cert.py --cluster <cluster.json>")
        sys.exit(1)

    # fetch cluster details file
    cluster_details = get_cluster_file(clusterfile)

    # Bi-directional bootstrapping
    if disaster_recovery:
        cluster_recovery(cluster_details)
        verify_dr_bootstrap(cluster_details)
        return 

    if isinstance(cluster_details.get('primary'), dict) and \
        (isinstance(cluster_details.get('targets'), list) or cluster_details.get('targets') == None):

        primary_cl_pw = cluster_details['primary'].get('password')
        primary_mfa = cluster_details['primary'].get('mfaCode')

        logger.info("Authenticating Cluster "+cluster_details['primary']['ip'])
        # authenticate
        apiauth(vip=cluster_details['primary']['ip'], username=cluster_details['primary']['username'], password=primary_cl_pw, mfaCode=primary_mfa)

        # exit if not authenticated
        if apiconnected() is False:
            logger.error('authentication failed for Cluster %s'+ cluster_details['primary']['ip'])
            exit(1)

        # Get Cluster software version
        cluster_version = get_cluster_version(cluster_details['primary']['ip'])
        if cluster_version is None:
            return

        # Enable only gflag if targets not provided
        if cluster_details.get('targets') == None:
            set_gflag(cluster_details['primary']['ip'])
            return

        # Get Cohesity CA keys
        primary_key, cert = ca_keys()


        bootstrap_targets(cluster_details['targets'], cert, primary_key, setflag=True)

    else:
        logger.error("Invalid JSON Format! Please provide Primary as Dict and Targets as list")
        exit(1)

if __name__ == '__main__':
    sys.exit(main())
