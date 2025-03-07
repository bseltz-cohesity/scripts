#!/usr/bin/env python3

from cryptography import x509
from cryptography.hazmat.primitives import serialization
from cryptography.x509 import DNSName, UniformResourceIdentifier
from cryptography.x509.oid import NameOID, ExtensionOID
from datetime import datetime
import requests
import sys
import os
import json
import urllib3
# import pyhesity wrapper module
from pyhesity import *

### ignore unsigned certificates
import requests.packages.urllib3

import logging

### command line arguments
import argparse
parser = argparse.ArgumentParser()

parser.add_argument('-c', '--config', type=str, default=None)
parser.add_argument('-g', '--generate', action='store_true')
parser.add_argument('-u', '--upload', action='store_true')

args = parser.parse_args()

cluster_certs_file = args.config
## If generate, upload are not provided, default is to generate from primary clusters and immediately upload to target vault cluster
generate = args.generate # generate certificates from primary clusters and save to certificates file
upload = args.upload # upload to target cluster from certificates file

requests.packages.urllib3.disable_warnings()

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Configure the logging settings
log_file_path = "generateAndUploadClusterCerts.log"  # Set the path to the log file
log_level = logging.DEBUG  # Set the desired log level

# Create a logger
logger = logging.getLogger("generateAndUploadClusterCerts")
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

def get_attribute(cert, oid):
    """ Helper function to extract certificate attributes safely
    """
    try:
        return cert.subject.get_attributes_for_oid(oid)[0].value
    except IndexError:
        return None

def generate_cert(existing_cert):
    """ Function to generate a certificate from cluster using it's CA

    Returns:
        String: PrivateKey, Certificate, CaCertificate
    """
    try:
        san_extension = existing_cert.extensions.get_extension_for_oid(ExtensionOID.SUBJECT_ALTERNATIVE_NAME)
        san_values = san_extension.value

        dns_names = [name.value for name in san_values if isinstance(name, DNSName)]
        uris = [name.value for name in san_values if isinstance(name, UniformResourceIdentifier)]
        san_list = dns_names + uris
    except x509.ExtensionNotFound:
        san_list = []

    expiry_date = existing_cert.not_valid_after
    current_time = datetime.utcnow()
    expiry_duration = expiry_date - current_time
    total_hours = int(expiry_duration.total_seconds() // 3600)
    go_duration_str = f"{total_hours}h"

    data = {
        "organization": get_attribute(existing_cert, NameOID.ORGANIZATION_NAME),
        "organizationUnit": get_attribute(existing_cert, NameOID.ORGANIZATIONAL_UNIT_NAME),
        "countryCode": get_attribute(existing_cert, NameOID.COUNTRY_NAME),
        "state": get_attribute(existing_cert, NameOID.STATE_OR_PROVINCE_NAME),
        "city": get_attribute(existing_cert, NameOID.LOCALITY_NAME),
        "commonName": get_attribute(existing_cert, NameOID.COMMON_NAME),
        "sanList": san_list,
        "duration": go_duration_str
    }

    logger.info("Certificate create request data:")
    logger.info(json.dumps(data, indent=4))

    try:
        # Send an HTTP POST request for cert
        response = api('post', 'cert-manager/cert', data=data, v=2)

        if response is not None:
            logger.info("Generated Cohesity cluster certificate")
            return response['privateKey'], response['certificate'], response['caCert'][0]
        else:
            logger.error(f"generate certificate request failed!")
            exit(1)

    except requests.exceptions.RequestException as e:
        logger.error(f"An error occurred: {e}")
        exit(1)

def download_magneto_cert():
    """ Function to download the Magneto cluster certificate from a Cohesity cluster

    Returns:
        magneto_certificate: Magneto Certificates from the Cluster
    """

    try:
        # Send an HTTP Get request to download certs
        response = api('get', 'cert-manager/download-cluster-cert', v=2)

        if response is not None:
            logger.info("Downloaded cluster certificates successfully")
            certs = response["certificates"]
            for cert_payload in certs:
                if "kMagneto" in cert_payload["serviceTypes"]:
                    logger.info("Found Magneto cluster certificate")
                    return cert_payload
        else:
            logger.error(f"download certificate request failed!")
            exit(1)

    except requests.exceptions.RequestException as e:
        logger.error(f"An error occurred: {e}")
        exit(1)

    return None

def upload_certs(certificates):
    """ Function to upload the certificates to a Cohesity cluster

    Args:
        certificates (List): List of Certificates to upload
    Returns:
        None
    """
    data = {
        "certificates": [
            {
                "privateKey": cert['privateKey'],
                "certPem": [cert['certificate']],
                "caChainPem": [cert['caCert']],
                "serviceTypes": ["kMagneto"]
            }
            for cert in certificates
        ]
    }
    logger.debug("Upload certificates payload: ")
    logger.debug(json.dumps(data, indent=4))
    
    try:
        # Send an HTTP POST request to upload certs
        response = api('post', 'cert-manager/upload-cluster-cert', data=data, v=2)

        if response is not None:
            logger.info("Uploaded cluster certificates successfully")
        else:
            logger.error(f"upload certificate request failed!")
            exit(1)

    except requests.exceptions.RequestException as e:
        logger.error(f"An error occurred: {e}")
        exit(1)


def generate_certs(primary_cluster_list, existing_magneto_cert):
    """Function to generate certificate from the primary clusters

    Args:
        primary_cluster_list (List): List of Primary Clusters
        existing_magneto_cert (x509): Existing Magneto certificate to copy fields from

    Returns:
        List: List of generated certificates
    """
    generated_certs = []

    for primary in primary_cluster_list:
        primary_mfa = None
        primary_password = None

        logger.info("Generating certificate started on Cluster from "+ primary['ip'])

        primary_password = primary.get('password')
        primary_mfa = primary.get('mfaCode')
        apiauth(vip=primary['ip'], username=primary['username'], password=primary_password, mfaCode=primary_mfa)

        if apiconnected() is False:
            logger.error('authentication failed for Cluster %s'+ primary['ip'])
            continue

        cluster_version = get_cluster_version(primary['ip'])

        if cluster_version is None:
            logger.error("Primary Cluster %s is not in supported version"+ primary['ip'])
            logger.error("Skipping generate certificate on Cluster IP "+ primary['ip'])
            continue


        key, cert, ca_cert = generate_cert(existing_cert=existing_magneto_cert)
        generated_certs.append({
            "ip": primary['ip'],
            "privateKey": key,
            "certificate": cert,
            "caCert": ca_cert
        })

        logger.debug("Generated certificates: " + json.dumps(generated_certs, indent=4))

    return generated_certs

def write_generated_certs_to_file(generated_certs):
    with open('generated_certs.json', 'w') as json_file:
        json.dump(generated_certs, json_file, indent=4)

def read_generated_certs_from_file():
    try:
        with open('generated_certs.json', 'r') as file:
            data = json.load(file)
        return data

    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error reading or parsing JSON file: {e}")
        return []

def download_magneto_cert_from_target(target_cluster_config):
    ''' Function to download existing Magneto cluster cert from the target cluster

    Returns:
        Magneto Cluster certificate
    '''
    target_mfa = None
    target_password = None

    logger.info("Downloading Magneto certificate from Cluster "+ target_cluster_config['ip'])

    target_password = target_cluster_config.get('password')
    target_mfa = target_cluster_config.get('mfaCode')
    apiauth(vip=target_cluster_config['ip'], username=target_cluster_config['username'], password=target_password, mfaCode=target_mfa)

    if apiconnected() is False:
        logger.error('authentication failed for Cluster %s'+ target_cluster_config['ip'])
        return

    cluster_version = get_cluster_version(target_cluster_config['ip'])

    if cluster_version is None:
        logger.error("Target Cluster %s is not in supported version"+ target_cluster_config['ip'])
        logger.error("Skipping download Magneto certificate on Cluster IP "+ target_cluster_config['ip'])
        return

    magneto_cert_payload = download_magneto_cert()
    if magneto_cert_payload:
        cert_pem = magneto_cert_payload["certPem"][0]
        cert_pem_bytes = cert_pem.encode()
        cert = x509.load_pem_x509_certificate(cert_pem_bytes)
        return cert

    logger.error("No valid Magneto certificate found on target cluster %s" + target_cluster_config['ip'])
    return None


def upload_certs_to_target(target_cluster_config, generated_certs):
    ''' Function to upload certificates to the target cluster

    Returns:
        None
    '''
    target_mfa = None
    target_password = None
    
    logger.info("Uploading certificate to Cluster from "+ target_cluster_config['ip'])

    target_password = target_cluster_config.get('password')
    target_mfa = target_cluster_config.get('mfaCode')
    apiauth(vip=target_cluster_config['ip'], username=target_cluster_config['username'], password=target_password, mfaCode=target_mfa)

    if apiconnected() is False:
        logger.error('authentication failed for Cluster %s'+ target_cluster_config['ip'])
        return

    cluster_version = get_cluster_version(target_cluster_config['ip'])

    if cluster_version is None:
        logger.error("Target Cluster %s is not in supported version"+ target_cluster_config['ip'])
        logger.error("Skipping upload certificate on Cluster IP "+ target_cluster_config['ip'])
        return
    
    upload_certs(generated_certs)


def get_config_file(cluster_certs_file):
    """ Function to read cluster certs file

    Returns:
        dict: Primary and Target vault Clusters, certficate parameters
    """

    # Get the absolute path of the cluster file
    cluster_file_path = os.path.abspath(cluster_certs_file)
    logger.info("Cluster certificate details found at "+ cluster_file_path)

    try:
        # Open the JSON file for reading
        with open(cluster_file_path, 'r') as json_file:
            # Load the JSON data into a Python dictionary
            cluster_certs_data = json.load(json_file)
            return cluster_certs_data
    except FileNotFoundError:
        logger.error(f"File '{cluster_file_path}' not found.")
        exit(1)
    except json.JSONDecodeError as e:
        logger.error(f"Error decoding JSON: {e}")
        exit(1)


def main():
    """
    Entry point to Certificate generation from primary clusters and upload to the target vault cluster
    """

    if cluster_certs_file is None:
        print("Usage: generateAndUploadClusterCerts.py --config <cluster-cert.json> [--generate] [--upload]")
        sys.exit(1)

    # fetch cluster certs file
    cluster_cert_details = get_config_file(cluster_certs_file)

    if isinstance(cluster_cert_details.get('target_vault_cluster'), dict) and \
        (isinstance(cluster_cert_details.get('primary_clusters'), list) or cluster_cert_details.get('primary_clusters') == None):

        existing_magneto_cert = download_magneto_cert_from_target(cluster_cert_details['target_vault_cluster'])
        if not existing_magneto_cert:
            logger.error("No existing Magneto certificate on target cluster found")
            exit(1)

        if generate:
            # Generate cluster certificates
            generated_certs = generate_certs(cluster_cert_details['primary_clusters'], existing_magneto_cert)
            write_generated_certs_to_file(generated_certs)
        elif upload:
            # Read generated certificates from file
            generated_certs = read_generated_certs_from_file()
            if not generated_certs:
                logger.error("No generated certificates provided to upload to target vault cluster")
                exit(1)
            # Upload certificates to target cluster
            upload_certs_to_target(cluster_cert_details['target_vault_cluster'], generated_certs)
        else:
            # Generate cluster certificates
            generated_certs = generate_certs(cluster_cert_details['primary_clusters'], existing_magneto_cert)
            # Upload certificates to target cluster
            upload_certs_to_target(cluster_cert_details['target_vault_cluster'], generated_certs)
    else:
        logger.error("Invalid JSON Format! Please provide Primary clusters as list and Target/cluster_parameters as Dict")
        exit(1)

if __name__ == '__main__':
    sys.exit(main())