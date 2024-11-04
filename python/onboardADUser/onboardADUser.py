#!/usr/bin/env python

from pyhesity import *
import codecs
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--vip', type=str, required=True)          # cluster to connect to
parser.add_argument('-u', '--username', type=str, default='helios')  # admin user to do the work
parser.add_argument('-d', '--domain', type=str, default='local')     # domain of admin user
parser.add_argument('-i', '--useApiKey', action='store_true')        # use API key for authentication
parser.add_argument('-p', '--password', type=str, default=None)      # password for admin user
parser.add_argument('-n', '--aduser', action='append', type=str)     # AD user to onboard
parser.add_argument('-l', '--aduserlist', type=str)                  # text file of ad users to onboard
parser.add_argument('-a', '--addomain', type=str, required=True)     # AD user to onboard
parser.add_argument('-desc', '--description', type=str, default='')  # AD user description
parser.add_argument('-keyname', '--keyname', type=str, default='')      # API key name
parser.add_argument('-r', '--role', type=str, default='COHESITY_VIEWER')    # Cohesity role to grant
parser.add_argument('-g', '--generateApiKey', action='store_true')          # generate new API key
parser.add_argument('-s', '--storeApiKey', action='store_true')             # store API key in file
parser.add_argument('-o', '--overwrite', action='store_true')               # overwrite existing API key

args = parser.parse_args()

vip = args.vip
username = args.username
domain = args.domain
useApiKey = args.useApiKey
password = args.password
adusers = args.aduser
aduserlist = args.aduserlist
addomain = args.addomain
description = args.description
keyname = args.keyname
role = args.role
generateApiKey = args.generateApiKey
storeApiKey = args.storeApiKey
overwrite = args.overwrite


# gather server list
def gatherList(param=None, filename=None, name='items', required=True):
    items = []
    if param is not None:
        for item in param:
            items.append(item)
    if filename is not None:
        f = open(filename, 'r')
        items += [s.strip() for s in f.readlines() if s.strip() != '']
        f.close()
    if required is True and len(items) == 0:
        print('no %s specified' % name)
        exit()
    return items


adusernames = gatherList(adusers, aduserlist, name='AD users', required=True)

# authenticate
apiauth(vip, username, domain, password=password, useApiKey=useApiKey)

if len(adusernames) > 1:
    outfile = 'apikeys.txt'
    f = codecs.open(outfile, 'w')

for aduser in adusernames:
    # get users
    users = [user for user in api('get', 'users') if user['username'].lower() == aduser.lower() and user['domain'].lower() == addomain.lower()]
    if len(users) == 0:
        # add user
        newUserParams = [
            {
                "principalName": aduser,
                "objectClass": "kUser",
                "roles": [
                    role
                ],
                "domain": addomain,
                "restricted": False,
                "description": description
            }
        ]
        print('Granting role: %s to user %s/%s...' % (role, addomain, aduser))
        newuser = api('post', 'activeDirectory/principals', newUserParams)
        users = [user for user in api('get', 'users') if user['username'].lower() == aduser.lower() and user['domain'].lower() == addomain.lower()]
    else:
        print('User %s/%s already on board...' % (addomain, aduser))

    # generate API Key
    if generateApiKey:
        sid = users[0]['sid']
        if keyname == '' or len(adusernames) > 1:
            keyname = '%s-key' % aduser

        keys = [key for key in api('get', 'usersApiKeys') if key['name'].lower() == keyname]
        if len(keys) > 0:
            if overwrite is True:
                deletekey = api('delete', 'users/%s/apiKeys/%s' % (sid, keys[0]['id']))
            else:
                print('api key already exists for %s' % aduser)
                exit(1)
        params = {
            'isActive': True,
            'user': users[0],
            'name': keyname
        }

        response = api('post', 'users/%s/apiKeys' % sid, params)

        if 'key' in response:
            if len(adusernames) > 1:
                f.write('%s %s\n' % (aduser, response['key']))
            if storeApiKey is True:
                setpwd(v=vip, u=aduser, d=addomain, password=response['key'], useApiKey=True)
            else:
                print('New API Key: %s' % response['key'])
        else:
            display(response)

if len(adusernames) > 1:
    f.close()
