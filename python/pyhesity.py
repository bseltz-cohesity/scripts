#!/usr/bin/env python
"""Cohesity Python REST API Wrapper Module - 2024.08.10"""

##########################################################################################
# Change Log
# ==========
#
# 2022.01.10 - updated password storage formats
# 2022.01.20 - added api context
# 2022.01.27 - added wildcard password storage for AD credentials
# 2022.02.04 - added support for V2 session authentication
# 2022.02.22 - Password retry for helios/MCM
# 2022.02.24 - Password retry for cluster ApiKey
# 2022.03.07 - Hide bad password in auth error
# 2022.05.19 - Fix MFA for session auth
# 2022.08.02 - Fixed password prompt=False processing
# 2022.09.11 - store password when passed from script, added caller to api log
# 2022.09.13 - added specific failure mode logging
# 2022.09.21 - better handling of bad API key scenarios
# 2022.11.26 - added v2 file download
# 2023.03.09 - added impersonate and switchback functions and improved tenant ID lookup
# 2023.03.30 - added try/except for log file
# 2023.04.30 - disabled email MFA and added timeout parameter
# 2023-09-06 - version bump
# 2023-09-24 - web session authentication, added support for password reset. email MFA
# 2023-10-03 - fixed 'forcePasswordChange' error on AD authentication
# 2023-10-09 - set last error on cluster not connected to helios
# 2023-10-13 - fixed password prompt for AD user
# 2023.11.07 - updated password storage after validation
# 2023.11.27 - fix useApiKey for helios/mcm
# 2023.12.29 - added testProp function
# 2024.01.14 - reenabled legacy access modes
# 2024.02.28 - added support for helios.gov
# 2024.03.15 - unhid value error
# 2024.03.31 - fixed empty return
# 2024.06.07 - added support for Entra ID (Open ID) authentication
# 2024.08.10 - added text output mode
#
##########################################################################################
# Install Notes
# =============
#
# Requires module: requests
# sudo easy_install requests
#         - or -
# sudo yum install python-requests
#
##########################################################################################

from datetime import datetime
import time
import json
import requests
import getpass
import base64
import os
import urllib3
import traceback
from os.path import expanduser

### ignore unsigned certificates
import requests.packages.urllib3

requests.packages.urllib3.disable_warnings()

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

__all__ = ['api_version',
           'LAST_API_ERROR',
           'apiauth',
           'api',
           'usecsToDate',
           'usecsToDateTime',
           'dateToUsecs',
           'dateToString',
           'timeAgo',
           'dayDiff',
           'display',
           'fileDownload',
           'fileUpload',
           'apiconnected',
           'apidrop',
           'pw',
           'setpwd',
           'testProp',
           'showProps',
           'storePasswordFromInput',
           'heliosCluster',
           'heliosClusters',
           'getContext',
           'setContext',
           'getDate',
           'impersonate',
           'switchback']

api_version = '2024.08.10'

COHESITY_API = {
    'APIROOT': '',
    'APIROOTv2': '',
    'HEADER': {},
    'AUTHENTICATED': False,
    'LAST_ERROR': 'OK',
    'SESSION': requests.Session()
}

COHESITY_API['SESSION'].headers.update({'User-Agent': 'pyhesity/%s' % api_version})

APIMETHODS = ['get', 'post', 'put', 'delete']
CONFIGDIR = expanduser("~") + '/.pyhesity'
SCRIPTDIR = os.path.dirname(os.path.realpath(__file__))
PWFILE = os.path.join(SCRIPTDIR, 'YWRtaW4')
LOGFILE = os.path.join(SCRIPTDIR, 'pyhesity-debug.log')
HELIOSENDPOINTS = ['helios.cohesity.com', 'helios.gov-cohesity.com']


### get last error
def LAST_API_ERROR():
    return COHESITY_API['LAST_ERROR']


### report auth error
def reportAuthError(e, quiet=None):
    COHESITY_API['AUTHENTICATED'] = False
    COHESITY_API['LAST_ERROR'] = e
    __writelog(e)
    if quiet is None:
        print(e)
    apidrop()


### authentication
def apiauth(vip='helios.cohesity.com', username='helios', domain='local', password=None, newPassword=None,
            updatepw=None, prompt=None, quiet=None, helios=False, useApiKey=False, tenantId=None, timeout=300,
            noretry=False, regionid=None, mfaType='Totp', mfaCode=None, emailMfaCode=False, 
            entraId=False, directoryId=None, clientId=None, scope='openid profile'):
    """authentication function"""
    global COHESITY_API
    global HELIOSCLUSTERS
    global CONNECTEDHELIOSCLUSTERS

    COHESITY_API['APIROOTMCM'] = 'https://%s/mcm/' % vip
    COHESITY_API['APIROOTMCMv2'] = 'https://%s/v2/mcm/' % vip
    COHESITY_API['APIROOTREPORTINGv2'] = 'https://%s/heliosreporting/api/v1/public/' % vip

    if '\\' in username:
        (domain, username) = username.split('\\')
    if '/' in username:
        (domain, username) = username.split('/')

    pwd = password
    setpasswd = None
    if pwd is not None:
        setpasswd = pwd
    else:
        pwd = __getpassword(vip=vip, username=username, password=password, domain=domain, useApiKey=useApiKey, helios=helios, updatepw=updatepw, prompt=prompt)
    if pwd is None:
        reportAuthError('no password provided for %s/%s at %s' % (domain, username, vip), quiet=quiet)
        return None
    COHESITY_API['HEADER'] = {'accept': 'application/json', 'content-type': 'application/json', 'User-Agent': 'pyhesity/%s' % api_version}
    COHESITY_API['APIROOT'] = 'https://' + vip + '/irisservices/api/v1'
    COHESITY_API['APIROOTv2'] = 'https://' + vip + '/v2/'
    if entraId is True and vip.lower() in HELIOSENDPOINTS:
        # entraId authentication
        if directoryId is None:
            directoryId = __getpassword(vip=vip, username=username, password=password, domain=domain, useApiKey=useApiKey, helios=helios, updatepw=updatepw, prompt=prompt, directoryId=True)
        if clientId is None:
            clientId = __getpassword(vip=vip, username=username, password=password, domain=domain, useApiKey=useApiKey, helios=helios, updatepw=updatepw, prompt=prompt, clientId=True)
        if clientId is not None and directoryId is not None and scope is not None:
            token = ProcessOidcToken(username=username, password=pwd, client_id=clientId, tenant_id=directoryId, scope=scope)
            if token is not None:
                COHESITY_API['HEADER'] = {'accept': 'application/json', 'content-type': 'application/json', 'X-OPEN-ID-AUTHZ-TOKEN': token, 'User-Agent': 'pyhesity/%s' % api_version}
            else:
                reportAuthError('Entra ID authentication failed', quiet=quiet)
                return None
        else:
            reportAuthError('Entra ID authentication failed', quiet=quiet)
            return None
        URL = COHESITY_API['APIROOTMCM'] + 'clusters/connectionStatus'
        HELIOSCLUSTERS = (COHESITY_API['SESSION'].get(URL, headers=COHESITY_API['HEADER'], verify=False, timeout=timeout)).json()
        if HELIOSCLUSTERS is not None and 'message' in HELIOSCLUSTERS:
            print(HELIOSCLUSTERS['message'])
            if 'Authentication failed' in HELIOSCLUSTERS['message'] and noretry is False and prompt is not False:
                apiauth(vip=vip, username=username, domain=domain, updatepw=True, prompt=prompt, helios=helios, useApiKey=useApiKey, quiet=True)
            else:
                reportAuthError('Helios/MCM authentication failed', quiet=quiet)
                return None
        if HELIOSCLUSTERS is not None and 'errorCode' not in HELIOSCLUSTERS:
            CONNECTEDHELIOSCLUSTERS = [cluster for cluster in HELIOSCLUSTERS if cluster['connectedToCluster'] is True]
            COHESITY_API['AUTHENTICATED'] = True
            COHESITY_API['LAST_ERROR'] = 'OK'
            if quiet is None:
                print("Connected!")
    elif vip.lower() in HELIOSENDPOINTS or helios is not False:
        # Helios/MCM API Key authentication
        COHESITY_API['HEADER'] = {'accept': 'application/json', 'content-type': 'application/json', 'apiKey': pwd, 'User-Agent': 'pyhesity/%s' % api_version}
        if regionid is not None:
            COHESITY_API['HEADER']['regionid'] = regionid
        URL = COHESITY_API['APIROOTMCM'] + 'clusters/connectionStatus'
        try:
            HELIOSCLUSTERS = (COHESITY_API['SESSION'].get(URL, headers=COHESITY_API['HEADER'], verify=False, timeout=timeout)).json()
            if HELIOSCLUSTERS is not None and 'message' in HELIOSCLUSTERS:
                print(HELIOSCLUSTERS['message'])
                if 'Authentication failed' in HELIOSCLUSTERS['message'] and noretry is False and prompt is not False:
                    apiauth(vip=vip, username=username, domain=domain, updatepw=True, prompt=prompt, helios=helios, useApiKey=useApiKey, quiet=True)
                else:
                    reportAuthError('Helios/MCM authentication failed', quiet=quiet)
                    return None
            if HELIOSCLUSTERS is not None and 'errorCode' not in HELIOSCLUSTERS:
                CONNECTEDHELIOSCLUSTERS = [cluster for cluster in HELIOSCLUSTERS if cluster['connectedToCluster'] is True]
                COHESITY_API['AUTHENTICATED'] = True
                COHESITY_API['LAST_ERROR'] = 'OK'
                if quiet is None:
                    print("Connected!")
            else:
                URL = COHESITY_API['APIROOTMCMv2'] + 'dms/regions'
                REGIONS = (COHESITY_API['SESSION'].get(URL, headers=COHESITY_API['HEADER'], verify=False, timeout=timeout)).json()
                if REGIONS is not None and 'message' in REGIONS:
                    reportAuthError('DMaaS authentication failed', quiet=quiet)
                    return None
                if REGIONS is not None and 'errorCode' not in REGIONS:
                    COHESITY_API['AUTHENTICATED'] = True
                    COHESITY_API['LAST_ERROR'] = 'OK'
                    if quiet is None:
                        print("Connected!")
            if setpasswd is not None:
                pwd = __getpassword(vip=vip, username=username, password=setpasswd, domain=domain, useApiKey=useApiKey, helios=helios, updatepw=updatepw, prompt=prompt)
            COHESITY_API['COOKIES'] = COHESITY_API['SESSION'].cookies.get_dict()
        except requests.exceptions.RequestException as e:
            reportAuthError(e, quiet=quiet)
            if 'Authentication failed' in e and noretry is False and prompt is not False and setpasswd is None:
                apiauth(vip=vip, username=username, domain=domain, updatepw=True, prompt=prompt, helios=helios, useApiKey=useApiKey)
    elif useApiKey is True:
        # Cluster API key authentication
        COHESITY_API['HEADER'] = {'accept': 'application/json', 'content-type': 'application/json', 'apiKey': pwd, 'User-Agent': 'pyhesity/%s' % api_version}
        COHESITY_API['AUTHENTICATED'] = True
        COHESITY_API['LAST_ERROR'] = 'OK'
        URL = COHESITY_API['APIROOT'] + '/public/sessionUser/preferences'
        cluster = (COHESITY_API['SESSION'].get(URL, headers=COHESITY_API['HEADER'], verify=False, timeout=timeout)).json()
        if cluster is not None and 'preferences' in cluster:
            if setpasswd is not None:
                pwd = __getpassword(vip=vip, username=username, password=setpasswd, domain=domain, useApiKey=useApiKey, helios=helios, updatepw=updatepw, prompt=prompt)
            if quiet is None:
                print("Connected!")
                COHESITY_API['COOKIES'] = COHESITY_API['SESSION'].cookies.get_dict()
            if tenantId is not None:
                impersonate(tenantId)
        else:
            if 'message' in cluster:
                COHESITY_API['LAST_ERROR'] = cluster['message']
            COHESITY_API['AUTHENTICATED'] = False
            if 'API Key does not exist' in COHESITY_API['LAST_ERROR'] or 'StatusUnauthorized' in COHESITY_API['LAST_ERROR'] or 'invalid header value' in COHESITY_API['LAST_ERROR']:
                COHESITY_API['LAST_ERROR'] = 'API key authentication failed'
                print('invalid API Key')
                if prompt is not False and noretry is not True and setpasswd is None:
                    apiauth(vip=vip, username=username, domain=domain, updatepw=True, prompt=prompt, helios=helios, useApiKey=useApiKey)
            else:
                print('Connection failed: %s' % COHESITY_API['LAST_ERROR'])
    else:
        # Username/password authentication
        creds = json.dumps({"domain": domain, "password": pwd, "username": username})
        url = 'https://' + vip + '/login'
        try:
            response = COHESITY_API['SESSION'].post(url, data=creds, headers=COHESITY_API['HEADER'], verify=False, timeout=timeout)
            if response != '':
                if response.status_code == 201 or response.status_code == 200:
                    COHESITY_API['AUTHENTICATED'] = True
                    # check force password change
                    try:
                        changePassword = False
                        user = response.json()
                        if 'user' in user and user['user'] is not None and 'forcePasswordChange' in user['user'] and user['user']['forcePasswordChange'] is True:
                            if newPassword is not None:
                                confirmPassword = newPassword
                                changePassword = True
                            else:
                                newPassword = '1'
                                confirmPassword = '2'
                                print('Password is expired')
                            if prompt is not False:
                                while newPassword != confirmPassword:
                                    newPassword = getpass.getpass("  Enter new password: ")
                                    confirmPassword = getpass.getpass("Confirm new password: ")
                                    if newPassword != confirmPassword:
                                        print('Passwords do not match')
                                changePassword = True
                            else:
                                reportAuthError('password is expired', quiet=quiet)
                                return None
                        else:
                            if newPassword is not None:
                                changePassword = True
                        if changePassword is True:
                            user['user']['currentPassword'] = pwd
                            user['user']['password'] = newPassword
                            api('put', 'users', user['user'])
                            creds = json.dumps({"domain": domain, "password": newPassword, "username": username})
                            response = COHESITY_API['SESSION'].post(url, data=creds, headers=COHESITY_API['HEADER'], verify=False, timeout=timeout)
                            if response != '':
                                if response.status_code == 201 or response.status_code == 200:
                                    COHESITY_API['AUTHENTICATED'] = True
                                    pwd = __getpassword(vip=vip, username=username, password=newPassword, domain=domain, useApiKey=useApiKey, helios=helios, updatepw=updatepw, prompt=prompt)
                                    setpasswd = None
                    except Exception as e:
                        reportAuthError(e, quiet=quiet)
                        return None
                    # mfa
                    if mfaCode is not None or emailMfaCode is True:
                        otpType = "Totp"
                        if emailMfaCode is True:
                            if user['user']['mfaInfo']['isEmailOtpSetupDone'] is False:
                                reportAuthError('Email MFA is not enabled for user', quiet=quiet)
                                return None
                            url = COHESITY_API['APIROOTv2'] + 'send-email-otp'
                            response = COHESITY_API['SESSION'].post(url, data=None, headers=COHESITY_API['HEADER'], verify=False, timeout=timeout)
                            mfaCode = getpass.getpass("Enter MFA Code: ")
                            otpType = 'Email'
                        try:
                            mfaCheck = json.dumps({
                                "otpCode": mfaCode,
                                "otpType": otpType
                            })
                            url = COHESITY_API['APIROOT'] + '/public/verify-otp'
                            response = COHESITY_API['SESSION'].post(url, data=mfaCheck, headers=COHESITY_API['HEADER'], verify=False, timeout=timeout)
                            if 'errorCode' in response.json():
                                if response.json()['errorCode'] == 'KValidationError':
                                    reportAuthError('MFA verification failed', quiet=quiet)
                                    return None
                        except Exception as e:
                            reportAuthError(e, quiet=quiet)
                            return None
                    # impersonate tenant
                    if tenantId is not None:
                        impersonate(tenantId)
                    COHESITY_API['LAST_ERROR'] = 'OK'
                    if setpasswd is not None:
                        pwd = __getpassword(vip=vip, username=username, password=setpasswd, domain=domain, useApiKey=useApiKey, helios=helios, updatepw=updatepw, prompt=prompt)
                    if quiet is None:
                        print("Connected!")
                    COHESITY_API['COOKIES'] = COHESITY_API['SESSION'].cookies.get_dict()
                else:
                    COHESITY_API['AUTHENTICATED'] = False
                    if response.status_code == 403 and 'user does not have the privilege to access ui' in response.json()['message'].lower():
                        # =============================================================================================================
                        creds = json.dumps({"domain": domain, "password": pwd, "username": username, "otpType": mfaType, "otpCode": mfaCode})
                        emailcreds = json.dumps({"domain": domain, "password": pwd, "username": username})

                        url = COHESITY_API['APIROOT'] + '/public/accessTokens'
                        try:
                            if emailMfaCode is True:
                                print('scripted MFA via email is disabled, please use -m xxxxxx')
                                apidrop()
                                return None

                            response = requests.post(url, data=creds, headers=COHESITY_API['HEADER'], verify=False, timeout=timeout)
                            if response != '':
                                if response.status_code == 201:
                                    accessToken = response.json()['accessToken']
                                    tokenType = response.json()['tokenType']
                                    COHESITY_API['HEADER'] = {
                                        'User-Agent': 'pyhesity/%s' % api_version,
                                        'accept': 'application/json',
                                        'content-type': 'application/json',
                                        'authorization': tokenType + ' ' + accessToken
                                    }
                                    COHESITY_API['AUTHENTICATED'] = True
                                    if tenantId is not None:
                                        impersonate(tenantId)
                                    COHESITY_API['LAST_ERROR'] = 'OK'
                                    if quiet is None:
                                        print("Connected!")
                                else:
                                    # try session auth
                                    if response.status_code == 400 and 'access denied' in response.json()['message'].lower():
                                        try:
                                            url = COHESITY_API['APIROOTv2'] + 'users/sessions'
                                            creds = json.dumps({"domain": domain, "password": pwd, "username": username, "otpType": mfaType.lower(), "otpCode": mfaCode})
                                            if emailMfaCode is True:
                                                creds = json.dumps({"domain": domain, "password": pwd, "username": username, "otpType": 'email', "otpCode": mfaCode})
                                            response = requests.post(url, data=creds, headers=COHESITY_API['HEADER'], verify=False, timeout=timeout)
                                            if response != '':
                                                if response.status_code == 201:
                                                    sessionId = response.json()['sessionId']
                                                    COHESITY_API['HEADER'] = {
                                                        'User-Agent': 'pyhesity/%s' % api_version,
                                                        'accept': 'application/json',
                                                        'content-type': 'application/json',
                                                        'session-id': sessionId
                                                    }
                                                    COHESITY_API['AUTHENTICATED'] = True
                                                    if tenantId is not None:
                                                        impersonate(tenantId)
                                                    COHESITY_API['LAST_ERROR'] = 'OK'
                                                    if quiet is None:
                                                        print("Connected!")
                                                else:
                                                    COHESITY_API['AUTHENTICATED'] = False
                                                    COHESITY_API['LAST_ERROR'] = 'Error %s' % response.status_code
                                                    __writelog('Error %s' % response.status_code)
                                                    if quiet is None:
                                                        print('Error %s' % response.status_code)
                                                    if response.status_code == 400 and 'invalid username' in response.json()['message'].lower():
                                                        if noretry is not True and prompt is not False:
                                                            apiauth(vip=vip, username=username, domain=domain, updatepw=True, prompt=prompt, helios=helios, useApiKey=useApiKey)
                                        except requests.exceptions.RequestException as e2:
                                            __writelog(e2)
                                            COHESITY_API['AUTHENTICATED'] = False
                                            COHESITY_API['LAST_ERROR'] = e2
                                            if quiet is None:
                                                print(e2)
                                    else:
                                        COHESITY_API['AUTHENTICATED'] = False
                                        if response.status_code == 400:
                                            COHESITY_API['LAST_ERROR'] = 'invalid username or password.'
                                        else:
                                            COHESITY_API['LAST_ERROR'] = 'Error %s' % response.status_code
                                        __writelog(COHESITY_API['LAST_ERROR'])
                                        if quiet is None:
                                            print(COHESITY_API['LAST_ERROR'])
                                        if response.status_code == 400 and 'invalid username' in response.json()['message'].lower():
                                            if noretry is False and prompt is not False:
                                                apiauth(vip=vip, username=username, domain=domain, updatepw=True, prompt=prompt, helios=helios, useApiKey=useApiKey)
                        except requests.exceptions.RequestException as e:
                            __writelog(e)
                            COHESITY_API['AUTHENTICATED'] = False
                            COHESITY_API['LAST_ERROR'] = e
                            if quiet is None:
                                print(e)
                        # =============================================================================================================
                        return None
                    if response.status_code == 400 or response.status_code == 401:
                        COHESITY_API['LAST_ERROR'] = 'invalid username or password'
                    else:
                        COHESITY_API['LAST_ERROR'] = 'Error %s' % response.status_code
                    __writelog(COHESITY_API['LAST_ERROR'])
                    if quiet is None:
                        print(COHESITY_API['LAST_ERROR'])
                    if (response.status_code == 400 or response.status_code == 401) and 'invalid username' in response.json()['message'].lower():
                        if noretry is False and prompt is not False and setpasswd is None:
                            apiauth(vip=vip, username=username, domain=domain, updatepw=True, prompt=prompt, helios=helios, useApiKey=useApiKey)
        except requests.exceptions.RequestException as e:
            reportAuthError(e, quiet=quiet)


def ProcessOidcToken(username, password, client_id, tenant_id, scope='openid profile'):
    callazure = None
    Azbody = {
        "grant_type": "password",
        "client_id": client_id,
        "scope": scope,
        "username": username,
        "password": password
    }
    AzureURL = "https://login.microsoftonline.com/%s/oauth2/v2.0/token" % tenant_id
    AzureHeader = {
        "content-type": "application/x-www-form-urlencoded;charset=utf-8",
        "Accept": "application/json"
    }

    # try:
    callazure = COHESITY_API['SESSION'].post(AzureURL, data=Azbody, headers=AzureHeader, verify=False)
    return callazure.json()['id_token']
    # except Exception:
    #     pass
    #     # print("EntraID authentication failed")
    return None


def apiconnected():
    return COHESITY_API['AUTHENTICATED']


def apidrop():
    global COHESITY_API
    COHESITY_API['AUTHENTICATED'] = False


def impersonate(tenantId):
    if COHESITY_API['AUTHENTICATED'] is True:
        tenants = api('get', 'tenants')
        if tenants is not None and len(tenants) > 0:
            thistenant = [t for t in tenants if t['name'].lower() == tenantId.lower()]
            if thistenant is not None and len(thistenant) > 0:
                COHESITY_API['HEADER']['x-impersonate-tenant-id'] = thistenant[0]['tenantId']
            else:
                print('tenant %s not found' % tenantId)
        else:
            print('tenant %s not found' % tenantId)


def switchback():
    if 'x-impersonate-tenant-id' in COHESITY_API['HEADER']:
        del COHESITY_API['HEADER']['x-impersonate-tenant-id']


def heliosCluster(clusterName=None, verbose=False):
    global COHESITY_API
    if clusterName is not None:
        if isinstance(clusterName, dict) is True:
            clusterName = clusterName['name']
        accessCluster = [cluster for cluster in CONNECTEDHELIOSCLUSTERS if cluster['name'].lower() == clusterName.lower()]
        if not accessCluster:
            print('Cluster %s not connected to Helios' % clusterName)
            COHESITY_API['LAST_ERROR'] = 'Cluster %s not connected to Helios' % clusterName
        else:
            COHESITY_API['HEADER']['accessClusterId'] = str(accessCluster[0]['clusterId'])
            COHESITY_API['LAST_ERROR'] = 'OK'
            if verbose is True:
                print('Using %s' % clusterName)
    else:
        print("\n{0:<20}{1:<36}{2}".format('ClusterID', 'SoftwareVersion', "ClusterName"))
        print("{0:<20}{1:<36}{2}".format('---------', '---------------', "-----------"))
        for cluster in sorted(CONNECTEDHELIOSCLUSTERS, key=lambda cluster: cluster['name'].lower()):
            print("{0:<20}{1:<36}{2}".format(cluster['clusterId'], cluster['softwareVersion'], cluster['name']))


def heliosClusters():
    return sorted(CONNECTEDHELIOSCLUSTERS, key=lambda cluster: cluster['name'].lower())


### api call function
def api(method, uri, data=None, quiet=None, mcm=None, mcmv2=None, v=1, reportingv2=None, context=None, timeout=300):
    """api call function"""
    if context is not None:
        THISCONTEXT = context
    else:
        THISCONTEXT = COHESITY_API
    if THISCONTEXT['AUTHENTICATED'] is False:
        print('Not Connected')
        return None
    response = ''
    if mcm is not None:
        url = THISCONTEXT['APIROOTMCM'] + uri
    elif mcmv2 is not None:
        url = THISCONTEXT['APIROOTMCMv2'] + uri
    elif reportingv2 is not None:
        url = THISCONTEXT['APIROOTREPORTINGv2'] + uri
    else:
        if v == 2:
            url = THISCONTEXT['APIROOTv2'] + uri
        else:
            if uri[0] != '/':
                uri = '/public/' + uri
            url = THISCONTEXT['APIROOT'] + uri

    if method in APIMETHODS:
        try:
            if method == 'get':
                response = COHESITY_API['SESSION'].get(url, headers=THISCONTEXT['HEADER'], verify=False, timeout=timeout)
            if method == 'post':
                response = COHESITY_API['SESSION'].post(url, headers=THISCONTEXT['HEADER'], json=data, verify=False, timeout=timeout)
            if method == 'put':
                response = COHESITY_API['SESSION'].put(url, headers=THISCONTEXT['HEADER'], json=data, verify=False, timeout=timeout)
            if method == 'delete':
                response = COHESITY_API['SESSION'].delete(url, headers=THISCONTEXT['HEADER'], json=data, verify=False, timeout=timeout)
            COHESITY_API['LAST_ERROR'] = 'OK'
        except requests.exceptions.RequestException as e:
            __writelog(e)
            COHESITY_API['LAST_ERROR'] = '%s' % e
            if quiet is None:
                print(e)

        if isinstance(response, bool):
            return ''
        if response != '':
            if response.status_code == 204:
                COHESITY_API['LAST_ERROR'] = response.reason
                return ''  # return None
            if response.status_code == 404:
                COHESITY_API['LAST_ERROR'] = response.reason
                if quiet is None:
                    print('Invalid api call: ' + uri)
                return None
            responsejson = None
            try:
                responsejson = response.json()
            except Exception:  # ValueError as ve:
                COHESITY_API['LAST_ERROR'] = response.reason
                if response.reason != 'OK':
                    print('*** %s ***' % response.reason)
                    return None
            if isinstance(responsejson, bool):
                return ''
            if responsejson is not None:
                if 'errorCode' in responsejson:
                    if 'message' in responsejson:
                        COHESITY_API['LAST_ERROR'] = responsejson['errorCode'][1:] + ': ' + responsejson['message']
                        if quiet is None:
                            print(responsejson['errorCode'][1:] + ': ' + responsejson['message'])
                            return {'error': responsejson['errorCode'][1:] + ': ' + responsejson['message']}
                        else:
                            return None
                    else:
                        if quiet is None:
                            print(responsejson)
                            return 'error'
                        else:
                            return None
                else:
                    return responsejson
            else:
                try:
                    responsetext = response.text
                    return responsetext
                except Exception:
                    return None
                
    else:
        if quiet is None:
            print("invalid api method")


### convert usecs to date string
def usecsToDate(uedate, fmt='%Y-%m-%d %H:%M:%S'):
    """Convert Unix Epoc Microseconds to Date String"""
    uedate = int(uedate) / 1000000
    return datetime.fromtimestamp(uedate).strftime(fmt)


### convert usecs to datetime object
def usecsToDateTime(uedate):
    """Convert Unix Epoc Microseconds to Date String"""
    uedate = int(uedate) / 1000000
    return datetime.fromtimestamp(uedate)


### convert date to usecs
def dateToUsecs(dt=datetime.now()):
    """Convert Date String to Unix Epoc Microseconds"""
    if isinstance(dt, str):
        dt = datetime.strptime(dt, "%Y-%m-%d %H:%M:%S")
    return int(time.mktime(dt.timetuple())) * 1000000


### convert date to string
def dateToString(dt, fmt='%Y-%m-%d %H:%M:%S'):
    """Convert date to date string"""
    return dt.strftime(fmt)


### get current date
def getDate():
    """get current date time"""
    return datetime.now()


### convert date difference to usecs
def timeAgo(timedelta, timeunit):
    """Convert Date Difference to Unix Epoc Microseconds"""
    nowsecs = int(time.mktime(datetime.now().timetuple())) * 1000000
    secs = {'seconds': 1, 'sec': 1, 'secs': 1,
            'minutes': 60, 'min': 60, 'mins': 60,
            'hours': 3600, 'hour': 3600,
            'days': 86400, 'day': 86400,
            'weeks': 604800, 'week': 604800,
            'months': 2628000, 'month': 2628000,
            'years': 31536000, 'year': 31536000}
    age = int(timedelta) * int(secs[timeunit.lower()]) * 1000000
    return nowsecs - age


def dayDiff(newdate, olddate):
    """Return number of days between usec dates"""
    return int(round((newdate - olddate) / float(86400000000)))


### get/store password for future runs
def __getpassword(vip, username, password, domain, useApiKey=False, helios=False, updatepw=False, prompt=True, directoryId=False, clientId=False):
    """get/set stored password"""
    if directoryId is True:
        useApiKey = 'directoryId'
    elif clientId is True:
        useApiKey = 'clientId'
    elif helios is True or vip.lower() in HELIOSENDPOINTS:
        useApiKey = False
    originalUsername = username
    originalVip = vip
    if domain.lower() != 'local' and helios is False and vip.lower() not in HELIOSENDPOINTS and useApiKey is False:
        originalUsername = "%s\\%s" % (domain, username)
        vip = '--'  # wildcard vip
    if os.path.exists(PWFILE):
        f = open(PWFILE, 'r')
        pwdlist = [e.strip() for e in f.readlines() if e.strip() != '']
        f.close()
        for pwditem in pwdlist:
            try:
                v, d, u, k, opwd = pwditem.split(":", 5)
                if v.lower() == vip.lower() and d.lower() == domain.lower() and u.lower() == username.lower() and k == str(useApiKey):
                    if password is not None:
                        setpwd(v=vip, u=username, d=domain, helios=helios, useApiKey=useApiKey, password=password)
                        return password
                    if updatepw is not None:
                        setpwd(v=vip, u=username, d=domain, helios=helios, useApiKey=useApiKey)
                        return pw(vip, username, domain)
                    else:
                        return base64.b64decode(opwd.encode('utf-8')).decode('utf-8')
            except Exception:
                pass
    pwpath = os.path.join(CONFIGDIR, vip + '-' + domain + '-' + username + '-' + str(useApiKey))
    if password is not None:
        pwd = password
        try:
            pwdfile = open(pwpath, 'w')
            opwd = base64.b64encode(pwd.encode('utf-8')).decode('utf-8')
            pwdfile.write(opwd)
            pwdfile.close()
            return pwd
        except Exception:
            __writelog('error storing password')
            print('error storing password')
            return pwd
    if updatepw is not None:
        if os.path.isfile(pwpath) is True:
            os.remove(pwpath)
    try:
        pwdfile = open(pwpath, 'r')
        opwd = pwdfile.read()
        pwd = base64.b64decode(opwd.encode('utf-8')).decode('utf-8')
        pwdfile.close()
        return pwd
    except Exception:
        if prompt is not False:
            __writelog('prompting for password...')
            if directoryId is True:
                pwd = getpass.getpass("Enter Directory ID for %s at %s: " % (originalUsername, originalVip))
            elif clientId is True:
                pwd = getpass.getpass("Enter Client ID for %s at %s: " % (originalUsername, originalVip))
            elif useApiKey is True:
                pwd = getpass.getpass("Enter API Key for %s at %s: " % (originalUsername, originalVip))
            else:
                pwd = getpass.getpass("Enter password for %s at %s: " % (originalUsername, originalVip))
            try:
                pwdfile = open(pwpath, 'w')
                opwd = base64.b64encode(pwd.encode('utf-8')).decode('utf-8')
                pwdfile.write(opwd)
                pwdfile.close()
                return pwd
            except Exception:
                print('error storing password')
                return pwd
        else:
            return None


# store password in PWFILE
def setpwd(v='helios.cohesity.com', u='helios', d='local', useApiKey=False, helios=False, password=None, entraId=False, directoryId=False, clientId=False):
    originalUsername = u
    originalVip = v
    if d.lower() != 'local' and helios is False and v.lower() not in HELIOSENDPOINTS and useApiKey is False:
        originalUsername = '%s\\%s' % (d, u)
        v = '--'  # wildcard vip
    if directoryId is True:
        useApiKey = 'directoryId'
    elif clientId is True:
        useApiKey = 'clientId'
    elif entraId is True:
        useApiKey = False
    if password is None:
        if directoryId is True:
            pwd = getpass.getpass("Enter Directory ID for %s at %s: " % (originalUsername, originalVip))
        elif clientId is True:
            pwd = getpass.getpass("Enter Client ID for %s at %s: " % (originalUsername, originalVip))
        elif useApiKey is True:
            pwd = getpass.getpass("Enter API key for %s at %s: " % (originalUsername, originalVip))
        else:
            pwd = getpass.getpass("Enter password for %s at %s: " % (originalUsername, originalVip))
    else:
        pwd = password
    opwd = base64.b64encode(pwd.encode('utf-8')).decode('utf-8')
    if os.path.exists(PWFILE):
        f = open(PWFILE, 'r')
        pwdlist = [e.strip() for e in f.readlines() if e.strip() != '']
        f.close()
    else:
        pwdlist = []
    f = open(PWFILE, 'w')
    foundPwd = False
    for pwditem in pwdlist:
        try:
            vip, domain, username, k, cpwd = pwditem.split(":", 5)
            if v.lower() == vip.lower() and d.lower() == domain.lower() and u.lower() == username.lower() and k == str(useApiKey):
                f.write('%s:%s:%s:%s:%s\n' % (v, d, u, useApiKey, opwd))
                foundPwd = True
            else:
                f.write('%s\n' % pwditem)
        except Exception:
            pass
    if foundPwd is False:
        f.write('%s:%s:%s:%s:%s\n' % (v, d, u, useApiKey, opwd))
    f.close()


### pwstore for alternate infrastructure
def pw(vip, username, domain='local', password=None, updatepw=None, useApiKey=False, helios=False, prompt=None):
    return __getpassword(vip, username, password, domain, useApiKey, helios, updatepw, prompt)


### store password from input
def storePasswordFromInput(vip, username, password, domain='local', useApiKey=False, helios=False):
    if domain.lower() != 'local' and helios is False and vip.lower() not in HELIOSENDPOINTS and useApiKey is False:
        vip = '--'  # wildcard vip
    pwpath = os.path.join(CONFIGDIR, vip + '-' + domain + '-' + username + '-' + str(useApiKey))
    try:
        pwdfile = open(pwpath, 'w')
        opwd = base64.b64encode(password.encode('utf-8')).decode('utf-8')
        pwdfile.write(opwd)
        pwdfile.close()
    except Exception:
        print('error trying to store password')


lastapierrorusecs = dateToUsecs()
lastapierror = ''


### debug log
def __writelog(logmessage):
    global lastapierrorusecs
    global lastapierror
    apidate = datetime.now()
    apierrordatestring = apidate.strftime("%Y-%m-%d-%H-%M-%S")
    apierrorusecs = dateToUsecs(apidate)

    try:
        # rotate log
        if os.path.exists(LOGFILE):
            logsize = os.path.getsize(LOGFILE)
            if logsize > 200000:
                os.rename(LOGFILE, '%s-%s.txt' % (LOGFILE, apierrordatestring))
    except Exception:
        pass

    # avoid race condition
    callstack = traceback.format_stack()[0].replace('\n', ' ').strip()
    apierror = '%s :: %s' % (callstack, logmessage)
    if apierror == lastapierror and apierrorusecs < (lastapierrorusecs + 5000000):
        time.sleep(5)
    try:
        # output log message
        debuglog = open(LOGFILE, 'a')
        debuglog.write('%s: %s\n' % (apierrordatestring, apierror))
        debuglog.close()
    except Exception:
        pass
    lastapierrorusecs = apierrorusecs
    lastapierror = apierror


### display json/dictionary as formatted text
def display(myjson):
    """prettyprint dictionary"""
    if isinstance(myjson, list):
        # handle list of results
        for result in myjson:
            print(json.dumps(result, sort_keys=True, indent=4, separators=(', ', ': ')))
    else:
        # or handle single result
        print(json.dumps(myjson, sort_keys=True, indent=4, separators=(', ', ': ')))


def fileDownload(uri, fileName, v=1, timeout=300):
    """download file"""
    if COHESITY_API['AUTHENTICATED'] is False:
        print('Not Connected')
        return None
    if 'https://' in uri.lower():
        url = uri
    else:
        if v == 2:
            url = COHESITY_API['APIROOTv2'] + uri
        else:
            if uri[0] != '/':
                uri = '/public/' + uri
            url = COHESITY_API['APIROOT'] + uri
    response = COHESITY_API['SESSION'].get(url, headers=COHESITY_API['HEADER'], verify=False, timeout=timeout, stream=True)
    f = open(fileName, 'wb')
    for chunk in response.iter_content(chunk_size=1048576):
        if chunk:
            f.write(chunk)
    f.close()


def fileUpload(uri, fileName, v=1, timeout=300):
    """upload file"""
    if COHESITY_API['AUTHENTICATED'] is False:
        print('Not Connected')
        return None
    if 'https://' in uri.lower():
        url = uri
    else:
        if v == 2:
            url = COHESITY_API['APIROOTv2'] + uri
        else:
            if uri[0] != '/':
                uri = '/public/' + uri
            url = COHESITY_API['APIROOT'] + uri
    try:
        files = {'file': open(fileName, 'rb')}
        response = COHESITY_API['SESSION'].post(url, files=files, headers=COHESITY_API['HEADER'], verify=False, timeout=timeout, cookies=COHESITY_API['COOKIES'])
    except Exception as e:
        print('fileUpload Error: %s' % e)


def testProp(obj, path=None):
    if obj is not None:
        if path is None or (path in obj and obj[path] is not None) and len(obj[path]) > 0:
            return True
    return False


def showProps(obj, parent='myobject', search=None):
    if isinstance(obj, dict):
        for key in sorted(obj):
            showProps(obj[key], "%s['%s']" % (parent, key), search)
    elif isinstance(obj, list):
        x = 0
        for item in obj:
            showProps(obj[x], "%s[%s]" % (parent, x), search)
            x = x + 1
    else:
        if search is not None:
            if search.lower() in parent.lower():
                print("%s = %s" % (parent, obj))
        else:
            print("%s = %s" % (parent, obj))


def getContext():
    return COHESITY_API.copy()


def setContext(context):
    global COHESITY_API
    if isinstance(context, dict) and 'HEADER' in context and 'APIROOT' in context and 'APIROOTv2' in context:
        COHESITY_API = context.copy()
    else:
        print('Invalid context')


### create CONFIGDIR if it doesn't exist
if os.path.isdir(CONFIGDIR) is False:
    try:
        os.mkdir(CONFIGDIR)
    except Exception:
        pass

##########################################################################################
# Old Change Log
# ==============
#
# 1.1 - added encrypted password storage - August 2017
# 1.2 - added date functions and private api access - April 2018
# 1.3 - simplified password encryption (weak!) to remove pycrypto dependency - April 2018
# 1.4 - improved error handling, added display function - May 2018
# 1.5 - added no content return - May 2018
# 1.6 - added dayDiff function - May 2018
# 1.7 - added password update feature - July 2018
# 1.8 - added support for None JSON returned - Jan 2019
# 1.9 - supressed HTTPS warning in Linux and PEP8 compliance - Feb 2019
# 1.9.1 - added support for interactive password prompt - Mar 2019
# 2.0 - python 3 compatibility - Mar 2019
# 2.0.1 - fixed date functions for pythion 3 - Mar 2019
# 2.0.2 - added file download - Jun 2019
# 2.0.3 - added silent error handling, apdrop(), apiconnected() - Jun 2019
# 2.0.4 - added pw and storepw - Aug 2019
# 2.0.5 - added showProps - Nov 2019
# 2.0.6 - handle another None return condition - Dec 2019
# 2.0.7 - added storePasswordFromInput function - Feb 2020
# 2.0.8 - added helios support - Mar 2020
# 2.0.9 - helios and error handling changes - Mar 2020
# 2.1.0 - added support for Iris API Key - May 2020
# 2.1.1 - added support for PWFILE - May 2020
# 2020.05.29 - added re-prompt for bad password, debug log, password storage changes
# 2020.06.04 - bumping version (no reason)
# 2020.06.16 - removed ansi codes from error message (Windows didn't display them correctly)
# 2020.07.10 - added support for tenant impersonation
# 2020.09.09 - fixed invalid password loop for PWFILE
# 2020.10.01 - added noretry for password checking
# 2021.02.16 - added V2 API support
# 2021.04.04 - added usecsToDateTime and fixed dateToUsecs to support datetime object as input
# 2021.04.08 - added support for readonly home dir
# 2021.04.20 - added error return from api function
# 2021.09.25 - added support for DMaaS
# 2021.10.13 - modified setpwd function
# 2021.11.10 - added setContext and getContext functions
# 2021.11.15 - added dateToString function, usecsToDate formatting, Helios Reporting v2, Helio On Prem
# 2021.11.18 - added support for multifactor authentication
# 2021.12.07 - added support for email multifactor authentication
# 2021.12.11 - dateToUsecs defaults to now, added getDate()
#
##########################################################################################
