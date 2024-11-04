#!/usr/bin/env python

from getpass import getpass

from pyVim import connect
# from pyVmomi import vim

### command line arguments
import argparse
parser = argparse.ArgumentParser()

parser.add_argument('-vc', '--vcenter', required=True)
parser.add_argument('-vu', '--viuser', required=True)
parser.add_argument('-vp', '--vipassword', default=None)

args = parser.parse_args()

if not args.vipassword:
    args.vipassword = getpass(prompt='Enter vcenter password: ')

# connect to vcenter
try:
    si = connect.SmartConnectNoSSL(host=args.vcenter,
                                   user=args.viuser,
                                   pwd=args.vipassword,
                                   port=443)
    print('Connected!')

except Exception:
    print("Unable to connect to %s" % args.vcenter)
    exit(1)
