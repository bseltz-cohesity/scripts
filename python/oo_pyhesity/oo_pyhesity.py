#!/usr/bin/env python
"""Cohesity Python REST API Class Library and Helper Functions - v0.1 - Brian Seltzer - December 2018"""

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
import os
from os.path import expanduser

### ignore unsigned certificates
import requests.packages.urllib3
requests.packages.urllib3.disable_warnings()

__all__ = ['CohesityCluster', 'usecsToDate', 'dateToUsecs', 'timeAgo', 'dayDiff', 'display']

CONFIGDIR = expanduser("~") + '/.pyhesity'


class CohesityCluster:
    debug = 0

    def __init__(self, server, username='admin', domain='local', updatepw=None):
        self.server = server
        __username = username
        __domain = domain
        __updatepw = updatepw
        self.APIROOT = 'https://' + self.server + '/irisservices/api/v1'
        __creds = json.dumps({"domain": __domain, "password": self.__getpassword(
            self.server, __username, __domain, __updatepw), "username": __username})
        self.__HEADER = {'accept': 'application/json', 'content-type': 'application/json'}
        __url = self.APIROOT + '/public/accessTokens'
        __response = requests.post(__url, data=__creds, headers=self.__HEADER, verify=False)
        if __response != '':
            if __response.status_code == 201:
                __accessToken = __response.json()['accessToken']
                __tokenType = __response.json()['tokenType']
                self.__HEADER = {'accept': 'application/json',
                                 'content-type': 'application/json',
                                 'authorization': __tokenType + ' ' + __accessToken}
                self.AUTHENTICATED = True
                if self.__class__.debug > 0:
                    print("Connected!")
            else:
                self.AUTHENTICATED = False
                __response.raise_for_status()

    ### get/store password for future runs
    def __getpassword(self, __vip, __username, __domain, __updatepw):
        """get/set stored password"""
        __pwpath = os.path.join(CONFIGDIR, 'lt.' + __vip + '.' + __username + '.' + __domain)
        if(__updatepw is True):
            if(os.path.isfile(__pwpath) is True):
                os.remove(__pwpath)
        try:
            __pwdfile = open(__pwpath, 'r')
            __pwd = ''.join(map(lambda num: chr(int(num) - 1), __pwdfile.read().split(', ')))
            __pwdfile.close()
            return __pwd
        except Exception:
            __pwd = "1"
            __pwd2 = "2"
            while (__pwd != __pwd2):
                __pwd = getpass.getpass("Enter your password: ")
                __pwd2 = getpass.getpass("Confirm your password: ")
                if(__pwd != __pwd2):
                    print("Passwords do not match. Try again:")
            __pwdfile = open(__pwpath, 'w')
            __pwdfile.write(', '.join(str(char) for char in list(map(lambda char: ord(char) + 1, __pwd))))
            __pwdfile.close()
            return __pwd

    def apicall(self, __method, __uri, __data=''):
        """api call function"""
        if self.AUTHENTICATED is False:
            return "Not Connected"
        __response = ''
        if __uri[0] != '/':
            __uri = '/public/' + __uri
        if __method == 'get':
            __response = requests.get(self.APIROOT + __uri, headers=self.__HEADER, verify=False)
        if __method == 'post':
            __response = requests.post(self.APIROOT + __uri, headers=self.__HEADER, json=__data, verify=False)
        if __method == 'put':
            __response = requests.put(self.APIROOT + __uri, headers=self.__HEADER, json=__data, verify=False)
        if __method == 'delete':
            __response = requests.delete(self.APIROOT + __uri, headers=self.__HEADER, json=__data, verify=False)
        if __response != '':
            if __response.status_code == 204:
                return ''
            if __response.status_code == 404:
                return 'Invalid api call: ' + __uri
            __responsejson = __response.json()
            if 'errorCode' in __responsejson:
                if 'message' in __responsejson:
                    print('\033[93m' + __responsejson['errorCode'][1:] + ': ' + __responsejson['message'] + '\033[0m')
                else:
                    print(__responsejson)
                return ''
            else:
                return __responsejson

    def get(self, __uri):
        return self.apicall('get', __uri)

    def post(self, __uri, __data):
        return self.apicall('post', __uri, __data)

    def put(self, __uri, __data):
        return self.apicall('post', __uri, __data)

    def delete(self, __uri, __data):
        return self.apicall('post', __uri, __data)


### convert usecs to date
def usecsToDate(uedate):
    """Convert Unix Epoc Microseconds to Date String"""
    uedate = int(uedate) / 1000000
    return datetime.fromtimestamp(uedate).strftime('%Y-%m-%d %H:%M:%S')


### convert date to usecs
def dateToUsecs(datestring):
    """Convert Date String to Unix Epoc Microseconds"""
    dt = datetime.strptime(datestring, "%Y-%m-%d %H:%M:%S")
    return int(time.mktime(dt.timetuple())) * 1000000


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
    print(newdate)
    print(olddate)
    return int(round((newdate - olddate) / float(86400000000)))


### display json/dictionary as formatted text
def display(myjson):
    """pretty print(dictionary"""
    if(isinstance(myjson, list)):
        # handle list of results
        for result in myjson:
            print(json.dumps(result, sort_keys=True, indent=4, separators=(', ', ': ')))
    else:
        # or handle single result
        print(json.dumps(myjson, sort_keys=True, indent=4, separators=(', ', ': ')))


### create CONFIGDIR if it doesn't exist
if os.path.isdir(CONFIGDIR) is False:
    os.mkdir(CONFIGDIR)
