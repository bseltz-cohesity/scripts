#!/usr/bin/env python
"""Tool for sending SMTP emails"""

# from smtptool import *
# smtp_connect('192.168.1.95',25)
# smtp_send('them@mydomain.net', 'me@mydomain.net', 'test2', 'hi')
# smtp_disconnect()

import smtplib

__all__ = ['smtp_connect', 'smtp_disconnect', 'smtp_send']


def smtp_connect(SMTP_SERVER, SMTP_PORT):
    global server
    server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)


def smtp_send(smtpfrom, smtpto, smtpsubject, smtptext):
    global server
    msg = 'Subject: {}\n\n{}'.format(smtpsubject, smtptext)
    server.sendmail(smtpfrom, smtpto, msg)


def smtp_disconnect():
    global server
    server.quit()
