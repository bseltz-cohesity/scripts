#!/usr/bin/env python
"""obfuscate logs - version 2026-06-08"""

import os
import gzip
import shutil
import re
import json
import codecs
import tarfile
from concurrent.futures import ProcessPoolExecutor
import time
import argparse

ignore_paths = [
    '/td',
    '/tr',
    '/th',
    '/a',
    '/table',
    '/tbody',
    '/thead',
    '/tracez',
    '/flagz',
    '/statz',
    '/pulsez',
    '/master',
    '/head',
    '/script',
    '/font',
    '/css',
    '/javascript',
    '/html',
    '/pre',
    '/br'
    '/#',
    '/.',
    '/(',
    '/<',
    '/^',
    '/=',
    '/%%s',
    '/tmp',
    '/root',
    '/amd64'
]

# Standard Linux system paths that are NOT sensitive and should not be redacted.
# These are well-known, non-identifying paths found commonly in system logs.
SAFE_LINUX_PATHS = frozenset([
    '/bin',
    '/sbin',
    '/usr',
    '/usr/bin',
    '/usr/sbin',
    '/usr/lib',
    '/usr/lib64',
    '/usr/local',
    '/usr/local/bin',
    '/usr/local/sbin',
    '/usr/share',
    '/etc',
    '/etc/hosts',
    '/etc/passwd',
    '/etc/group',
    '/etc/fstab',
    '/etc/resolv.conf',
    '/etc/sudoers',
    '/etc/ssh',
    '/etc/systemd',
    '/etc/init.d',
    '/etc/cron.d',
    '/etc/cron.daily',
    '/etc/cron.weekly',
    '/etc/cron.monthly',
    '/etc/profile',
    '/etc/profile.d',
    '/etc/environment',
    '/etc/os-release',
    '/etc/hostname',
    '/etc/timezone',
    '/etc/localtime',
    '/etc/default',
    '/etc/sysctl.conf',
    '/etc/sysctl.d',
    '/etc/security',
    '/etc/pam.d',
    '/etc/ld.so.conf',
    '/etc/ld.so.conf.d',
    '/etc/modprobe.d',
    '/etc/modules',
    '/etc/udev',
    '/etc/network',
    '/etc/netplan',
    '/etc/NetworkManager',
    '/lib',
    '/lib64',
    '/lib/systemd',
    '/lib/modules',
    '/proc',
    '/proc/cpuinfo',
    '/proc/meminfo',
    '/proc/mounts',
    '/proc/net',
    '/proc/sys',
    '/proc/self',
    '/sys',
    '/sys/class',
    '/sys/block',
    '/sys/bus',
    '/sys/devices',
    '/sys/kernel',
    '/sys/module',
    '/sys/power',
    '/dev',
    '/dev/null',
    '/dev/zero',
    '/dev/random',
    '/dev/urandom',
    '/dev/stdin',
    '/dev/stdout',
    '/dev/stderr',
    '/dev/sda',
    '/dev/sdb',
    '/dev/loop0',
    '/dev/mapper',
    '/run',
    '/run/lock',
    '/run/user',
    '/tmp',
    '/var',
    '/var/run',
    '/var/lock',
    '/var/log',
    '/var/log/syslog',
    '/var/log/auth.log',
    '/var/log/kern.log',
    '/var/log/dmesg',
    '/var/log/messages',
    '/var/log/secure',
    '/var/log/faillog',
    '/var/log/lastlog',
    '/var/log/wtmp',
    '/var/log/btmp',
    '/var/lib',
    '/var/cache',
    '/var/spool',
    '/var/tmp',
    '/var/www',
    '/opt',
    '/boot',
    '/boot/grub',
    '/home',
    '/mnt',
    '/media',
    '/srv',
    '/snap',
    '/usr/bin/python',
    '/usr/bin/python3',
    '/usr/bin/python2',
    '/usr/bin/perl',
    '/usr/bin/bash',
    '/usr/bin/sh',
    '/usr/bin/env',
    '/usr/bin/awk',
    '/usr/bin/sed',
    '/usr/bin/grep',
    '/usr/bin/find',
    '/usr/bin/xargs',
    '/usr/bin/cut',
    '/usr/bin/sort',
    '/usr/bin/uniq',
    '/usr/bin/wc',
    '/usr/bin/head',
    '/usr/bin/tail',
    '/usr/bin/cat',
    '/usr/bin/echo',
    '/usr/bin/printf',
    '/usr/bin/ls',
    '/usr/bin/cp',
    '/usr/bin/mv',
    '/usr/bin/rm',
    '/usr/bin/mkdir',
    '/usr/bin/rmdir',
    '/usr/bin/chmod',
    '/usr/bin/chown',
    '/usr/bin/chgrp',
    '/usr/bin/ln',
    '/usr/bin/stat',
    '/usr/bin/touch',
    '/usr/bin/file',
    '/usr/bin/which',
    '/usr/bin/whereis',
    '/usr/bin/tar',
    '/usr/bin/gzip',
    '/usr/bin/gunzip',
    '/usr/bin/zip',
    '/usr/bin/unzip',
    '/usr/bin/curl',
    '/usr/bin/wget',
    '/usr/bin/ssh',
    '/usr/bin/scp',
    '/usr/bin/rsync',
    '/usr/bin/git',
    '/usr/bin/make',
    '/usr/bin/gcc',
    '/usr/bin/g++',
    '/usr/bin/java',
    '/usr/bin/javac',
    '/usr/bin/node',
    '/usr/bin/npm',
    '/usr/bin/systemctl',
    '/usr/bin/journalctl',
    '/usr/bin/ps',
    '/usr/bin/top',
    '/usr/bin/htop',
    '/usr/bin/kill',
    '/usr/bin/killall',
    '/usr/bin/pkill',
    '/usr/bin/pgrep',
    '/usr/bin/df',
    '/usr/bin/du',
    '/usr/bin/mount',
    '/usr/bin/umount',
    '/usr/bin/lsblk',
    '/usr/bin/blkid',
    '/usr/bin/fdisk',
    '/usr/bin/parted',
    '/usr/bin/lsof',
    '/usr/bin/netstat',
    '/usr/bin/ss',
    '/usr/bin/ip',
    '/usr/bin/ifconfig',
    '/usr/bin/ping',
    '/usr/bin/traceroute',
    '/usr/bin/nmap',
    '/usr/bin/tcpdump',
    '/usr/bin/strace',
    '/usr/bin/ltrace',
    '/usr/bin/ldd',
    '/usr/bin/nm',
    '/usr/bin/objdump',
    '/usr/bin/readelf',
    '/usr/bin/strings',
    '/usr/bin/xxd',
    '/usr/bin/hexdump',
    '/usr/bin/md5sum',
    '/usr/bin/sha1sum',
    '/usr/bin/sha256sum',
    '/usr/bin/openssl',
    '/usr/bin/passwd',
    '/usr/bin/useradd',
    '/usr/bin/userdel',
    '/usr/bin/usermod',
    '/usr/bin/groupadd',
    '/usr/bin/groupdel',
    '/usr/bin/groupmod',
    '/usr/bin/id',
    '/usr/bin/whoami',
    '/usr/bin/su',
    '/usr/bin/sudo',
    '/usr/bin/crontab',
    '/usr/bin/at',
    '/usr/bin/batch',
    '/usr/bin/nohup',
    '/usr/bin/screen',
    '/usr/bin/tmux',
    '/usr/bin/vim',
    '/usr/bin/vi',
    '/usr/bin/nano',
    '/usr/bin/emacs',
    '/usr/sbin/sshd',
    '/usr/sbin/nginx',
    '/usr/sbin/apache2',
    '/usr/sbin/httpd',
    '/usr/sbin/mysqld',
    '/usr/sbin/postgres',
    '/usr/sbin/crond',
    '/usr/sbin/atd',
    '/usr/sbin/rsyslogd',
    '/usr/sbin/syslogd',
    '/usr/sbin/init',
    '/usr/sbin/service',
    '/usr/sbin/update-rc.d',
    '/usr/sbin/chkconfig',
    '/usr/sbin/iptables',
    '/usr/sbin/ip6tables',
    '/usr/sbin/ufw',
    '/usr/sbin/firewalld',
    '/usr/sbin/semanage',
    '/usr/sbin/restorecon',
    '/usr/sbin/getenforce',
    '/usr/sbin/setenforce',
    '/usr/sbin/useradd',
    '/usr/sbin/userdel',
    '/usr/sbin/usermod',
    '/usr/sbin/groupadd',
    '/usr/sbin/visudo',
    '/usr/sbin/lvs',
    '/usr/sbin/pvs',
    '/usr/sbin/vgs',
    '/usr/sbin/lvcreate',
    '/usr/sbin/lvremove',
    '/usr/sbin/lvextend',
    '/usr/sbin/lvreduce',
    '/usr/sbin/pvcreate',
    '/usr/sbin/vgcreate',
    '/usr/sbin/fdisk',
    '/usr/sbin/parted',
    '/usr/sbin/mkfs',
    '/usr/sbin/fsck',
    '/usr/sbin/e2fsck',
    '/usr/sbin/tune2fs',
    '/usr/sbin/dumpe2fs',
    '/usr/sbin/blkid',
    '/usr/sbin/hwclock',
    '/usr/sbin/ntpdate',
    '/usr/sbin/chronyd',
    '/bin/bash',
    '/bin/sh',
    '/bin/dash',
    '/bin/zsh',
    '/bin/ksh',
    '/bin/csh',
    '/bin/tcsh',
    '/bin/ls',
    '/bin/cat',
    '/bin/cp',
    '/bin/mv',
    '/bin/rm',
    '/bin/mkdir',
    '/bin/rmdir',
    '/bin/chmod',
    '/bin/chown',
    '/bin/ln',
    '/bin/echo',
    '/bin/grep',
    '/bin/sed',
    '/bin/awk',
    '/bin/find',
    '/bin/sort',
    '/bin/uniq',
    '/bin/wc',
    '/bin/head',
    '/bin/tail',
    '/bin/ps',
    '/bin/kill',
    '/bin/df',
    '/bin/du',
    '/bin/mount',
    '/bin/umount',
    '/bin/ping',
    '/bin/su',
    '/bin/login',
    '/bin/tar',
    '/bin/gzip',
    '/bin/gunzip',
    '/bin/systemctl',
    '/bin/journalctl',
    '/bin/hostname',
    '/bin/uname',
    '/bin/date',
    '/bin/pwd',
    '/bin/true',
    '/bin/false',
    '/bin/sleep',
    '/bin/lsblk',
    '/sbin/init',
    '/sbin/shutdown',
    '/sbin/reboot',
    '/sbin/halt',
    '/sbin/poweroff',
    '/sbin/modprobe',
    '/sbin/insmod',
    '/sbin/rmmod',
    '/sbin/lsmod',
    '/sbin/depmod',
    '/sbin/sysctl',
    '/sbin/iptables',
    '/sbin/ip6tables',
    '/sbin/ifconfig',
    '/sbin/ip',
    '/sbin/route',
    '/sbin/arp',
    '/sbin/ethtool',
    '/sbin/iwconfig',
    '/sbin/iwlist',
    '/sbin/dhclient',
    '/sbin/fdisk',
    '/sbin/parted',
    '/sbin/mkfs',
    '/sbin/fsck',
    '/sbin/e2fsck',
    '/sbin/blkid',
    '/sbin/blockdev',
    '/sbin/lvs',
    '/sbin/pvs',
    '/sbin/vgs',
    '/sbin/lvcreate',
    '/sbin/lvremove',
    '/sbin/pvcreate',
    '/sbin/vgcreate',
    '/sbin/useradd',
    '/sbin/userdel',
    '/sbin/usermod',
    '/sbin/groupadd',
    '/sbin/ldconfig',
    '/sbin/swapon',
    '/sbin/swapoff',
    '/sbin/mkswap',
])

# Regex to quickly test whether a path starts with a known safe prefix.
# We compile a single pattern for speed.
_SAFE_PREFIX_RE = re.compile(
    r'^(?:' +
    '|'.join(re.escape(p) for p in sorted(SAFE_LINUX_PATHS, key=len, reverse=True)) +
    r')(?:[/\s,;"\']|$)'
)


def is_safe_linux_path(path: str) -> bool:
    """Return True if *path* is a standard, non-sensitive Linux system path."""
    stripped = path.strip()
    if stripped in SAFE_LINUX_PATHS:
        return True
    return bool(_SAFE_PREFIX_RE.match(stripped))


match_paths = [
    '/system.slice/',
    '/user.slice/',
    '/home/cohesity',
    '/home_cohesity_data',
    '/cohesity_users_home*',
    '/home/support/',
    '/COHESITY_YODA',
    '/cohesity_logs',
    '/healthz',
    '/sys/fs/cgroup',
    '/var/log/cohesity',
    '/var/run/ovn/',
    '/usr/bin/',
    '/bin/systemctl',
    '/status OVN',
    '/C) ,latency (us)',
    '/usr/bin',
    '/etc/ora',
    '/usr/sbin/lvs',
    '/run for volume',
    'for volume tmpfs',
    '/bin/bash',
    '/bin/lsblk',
    '/usr/sbin/',
    '/ ; USER',
    '/healthsize',
    '//www.rsyslog.com',
    '.go:',
    '/var/run/openvswitch',
    '/var/log/audit',
    '/selinux/targeted/active/modules',
    'commit_changessize: ',
    '/root ; USER',
    '/var/log/openvswitch',
    '//support.cohesity.com/',
    '/siren/v1/',
    '/pprof/heapstats from ',
    '/metrics from ',
    '/cohesity_users_home/support',
    '/threadz from ',
    '/varz from ',
    '/flagz from ',
    '/portz from ',
    '/statsz from ',
    '/tracez?component'
]

IGNORE_PATHS = frozenset(ignore_paths)
RE_MATCH_PATHS = re.compile('|'.join(re.escape(p) for p in match_paths))
RE_TAGS = re.compile(r'(<.*?[\w:|\.|-|"|=]+>)')
RE_SPLIT_LINE = re.compile(r'[="\[><]')
RE_WIN_PATH = re.compile(r'(\\.+[\w:.|\\-]+)')
RE_LINUX_PATH = re.compile(r'(\/.+[\w:.|\\-]+)')

crlist = None

# ---------------------------------------------------------------------------
# Multi-line buffer size: number of lines to hold in a sliding window so that
# custom-rule patterns that span a newline can still be matched.
# ---------------------------------------------------------------------------
MULTILINE_BUFFER_SIZE = 5


class RedactionRegistry:
    """Maps each unique original string to a stable, unique redaction token.

    Token format: <prefix>_<zero-padded counter>
    Example: redacted_path_001, redacted_path_002, ...

    The same original value always gets the same token within a registry
    instance (i.e. within a single file's processing run).
    """

    def __init__(self):
        # { prefix -> { original_value -> token } }
        self._maps = {}
        # { prefix -> current counter }
        self._counters = {}

    def redact(self, original: str, prefix: str) -> str:
        """Return the stable redaction token for *original* under *prefix*."""
        if prefix not in self._maps:
            self._maps[prefix] = {}
            self._counters[prefix] = 0
        mapping = self._maps[prefix]
        if original not in mapping:
            self._counters[prefix] += 1
            mapping[original] = f'{prefix}_{self._counters[prefix]:03d}'
        return mapping[original]


# ---------------------------------------------------------------------------
# Filename redaction
# ---------------------------------------------------------------------------

def redact_filename(filename: str, crlist, registry: 'RedactionRegistry') -> str:
    """Apply custom redaction rules to a filename (base name only).

    Returns the (possibly modified) filename. If no rules match, the original
    filename is returned unchanged.
    """
    if crlist is None:
        return filename

    new_name = filename
    for rule in crlist:
        matches = re.findall(rule['regex'], new_name)
        prefix = rule.get('type', 'redacted_rule')
        for match in matches:
            if isinstance(match, tuple):
                for submatch in match:
                    if submatch:
                        token = registry.redact(submatch, prefix)
                        new_name = new_name.replace(submatch, token)
            else:
                token = registry.redact(match, prefix)
                new_name = new_name.replace(match, token)
    return new_name


# ---------------------------------------------------------------------------
# Multi-line custom-rule application
# ---------------------------------------------------------------------------

def apply_custom_rules_to_substring(value: str, crlist, registry: 'RedactionRegistry') -> str:
    """Apply custom redaction rules to an arbitrary substring (e.g. a path or
    filename component).  This ensures that sensitive patterns embedded inside
    a larger token — such as an IP address inside a folder name — are redacted
    before the surrounding string is stored or written.

    Returns the value with any matching substrings replaced by their tokens.
    """
    if crlist is None or not value:
        return value
    for rule in crlist:
        matches = re.findall(rule['regex'], value)
        prefix = rule.get('type', 'redacted_rule')
        for match in matches:
            if isinstance(match, tuple):
                for submatch in match:
                    if submatch:
                        token = registry.redact(submatch, prefix)
                        value = value.replace(submatch, token)
            else:
                token = registry.redact(match, prefix)
                value = value.replace(match, token)
    return value


def apply_custom_rules_multiline(lines: list, crlist, registry: 'RedactionRegistry') -> list:
    """Apply custom rules to a sliding window of lines so that patterns
    spanning newlines are matched and redacted.

    *lines* is a list of raw line strings (including newline characters).
    Returns a new list of lines with redactions applied.
    """
    if crlist is None or not lines:
        return lines

    # Join the buffer into a single string, apply each rule, then re-split
    # back to individual lines — preserving the original line boundaries.
    joined = ''.join(lines)
    for rule in crlist:
        matches = re.findall(rule['regex'], joined)  # flags already compiled into pattern
        prefix = rule.get('type', 'redacted_rule')
        for match in matches:
            if isinstance(match, tuple):
                for submatch in match:
                    if submatch:
                        token = registry.redact(submatch, prefix)
                        joined = joined.replace(submatch, token)
            else:
                token = registry.redact(match, prefix)
                joined = joined.replace(match, token)

    # Re-split on newlines, preserving the terminator on each line.
    result = []
    remaining = joined
    for original_line in lines:
        # Each original line determines how many characters to peel off.
        result.append(remaining[: len(original_line)])
        remaining = remaining[len(original_line):]
    return result


# ---------------------------------------------------------------------------
# Core file obfuscation
# ---------------------------------------------------------------------------

def obfuscatefile(root, filepath, crlist):
    filename = os.path.basename(filepath)
    print(filepath, flush=True)
    if filename.startswith('redacted_'):
        return

    # One registry per file so tokens are consistent within a file
    registry = RedactionRegistry()

    # --- Change 3: Redact the filename itself ---
    new_filename = redact_filename(filename, crlist, registry)
    if new_filename != filename:
        new_filepath = os.path.join(root, new_filename)
        os.replace(filepath, new_filepath)
        filepath = new_filepath
        filename = new_filename
        print(f'  filename redacted -> {filename}', flush=True)

    outfile = os.path.join(root, 'redacted_%s' % filename)
    with codecs.open(filepath, 'r', 'latin-1') as f_in:
        with codecs.open(outfile, 'w', 'latin-1') as f_out:

            # --- Change 2: sliding window for multi-line custom-rule matching ---
            # We buffer up to MULTILINE_BUFFER_SIZE lines, flush when the buffer
            # is full (emitting the oldest line after applying cross-line rules).
            line_buffer: list = []

            def flush_buffer(force: bool = False):
                """Process and write lines from the buffer.

                If *force* is False only the oldest line (index 0) is written;
                this keeps the window size stable. If *force* is True all
                remaining lines are written (used at EOF).
                """
                nonlocal line_buffer
                if not line_buffer:
                    return

                # Apply custom rules across the whole window (multi-line aware)
                line_buffer = apply_custom_rules_multiline(line_buffer, crlist, registry)

                if force:
                    lines_to_write = line_buffer
                    line_buffer = []
                else:
                    lines_to_write = [line_buffer[0]]
                    line_buffer = line_buffer[1:]

                for line in lines_to_write:
                    processed = _process_single_line(line, registry, crlist)
                    f_out.write(processed)

            for raw_line in f_in:
                line_buffer.append(raw_line)
                if len(line_buffer) >= MULTILINE_BUFFER_SIZE:
                    flush_buffer(force=False)

            # Flush remaining lines
            flush_buffer(force=True)

    os.remove(filepath)
    os.replace(outfile, filepath)


def _process_single_line(line: str, registry: 'RedactionRegistry', crlist=None) -> str:
    """Apply per-line redaction rules (entity=, path=, Linux/Windows paths, etc.).

    Custom rules have already been applied by the time this function is called.
    """
    skipline = bool(RE_MATCH_PATHS.search(line))
    if skipline is False:
        # rules for non-paths
        if 'entity=' in line:
            lineparts = line.split('entity=')
            if len(lineparts) > 0:
                lineparts2 = lineparts[1].split(',')
                if len(lineparts2) > 0:
                    original = lineparts2[0]
                    redacted_original = apply_custom_rules_to_substring(original, crlist, registry)
                    token = registry.redact(redacted_original, 'redacted_entity')
                    securefile = f'entity={original}'
                    line = line.replace(securefile, f'entity={token}')
        if 'update_documents_function_arg: "' in line:
            lineparts = line.split('update_documents_function_arg: "')
            if len(lineparts) > 0:
                lineparts2 = lineparts[1].split('"')
                if len(lineparts2) > 0:
                    original = lineparts2[0]
                    redacted_original = apply_custom_rules_to_substring(original, crlist, registry)
                    token = registry.redact(redacted_original, 'redacted_arg')
                    securefile = f'update_documents_function_arg: "{original}"'
                    line = line.replace(securefile, f'update_documents_function_arg: "{token}"')
        # rules for paths
        if ('/' in line or '\\' in line):
            if 'path=' in line:
                lineparts = line.split('path=')
                if len(lineparts) > 0:
                    lineparts2 = lineparts[1].split(',')
                    if len(lineparts2) > 0:
                        raw_original = lineparts2[0]
                        # --- Change 1: skip safe Linux paths ---
                        if not is_safe_linux_path(raw_original):
                            redacted_original = apply_custom_rules_to_substring(raw_original, crlist, registry)
                            token = registry.redact(redacted_original, 'redacted_path')
                            securefile = f'path={raw_original},'
                            line = line.replace(securefile, f'path={token},')
            if 'entry=' in line:
                lineparts = line.split('entry=')
                if len(lineparts) > 0:
                    lineparts2 = lineparts[1].split(' in dir')
                    if len(lineparts2) > 0:
                        raw_original = lineparts2[0]
                        if not is_safe_linux_path(raw_original):
                            redacted_original = apply_custom_rules_to_substring(raw_original, crlist, registry)
                            token = registry.redact(redacted_original, 'redacted_entry')
                            securefile = f'entry={raw_original}'
                            line = line.replace(securefile, f'entry={token}')
            if 'dir_sync_tx2_op.cc' in line:
                lineparts = line.split('Looking up ')
                if len(lineparts) > 1:
                    lineparts2 = lineparts[1].split(' in dir')
                    if len(lineparts2) > 1:
                        raw_original = lineparts2[0]
                        if not is_safe_linux_path(raw_original):
                            redacted_original = apply_custom_rules_to_substring(raw_original, crlist, registry)
                            token = registry.redact(redacted_original, 'redacted_path')
                            line = line.replace(f'Looking up {raw_original}', f'Looking up {token}')
                lineparts = line.split('for entry=')
                if len(lineparts) > 1:
                    lineparts2 = lineparts[1].split(' in dir=')
                    if len(lineparts2) > 1:
                        raw_original = lineparts2[0]
                        if not is_safe_linux_path(raw_original):
                            redacted_original = apply_custom_rules_to_substring(raw_original, crlist, registry)
                            token = registry.redact(redacted_original, 'redacted_entry')
                            line = line.replace(f'entry={raw_original}', f'entry={token}')
            tags = ''.join(re.findall(RE_TAGS, line))
            lineparts = re.split(RE_SPLIT_LINE, line)
            for linepart in lineparts:
                windowspaths = re.findall(RE_WIN_PATH, linepart)
                paths = [p for p in windowspaths if p not in tags and p not in [i for i in IGNORE_PATHS]]
                for path in paths:
                    redacted_path = apply_custom_rules_to_substring(path, crlist, registry)
                    token = registry.redact(redacted_path, 'redacted_path')
                    line = line.replace(path, f'\\{token}')
            lineparts = re.split('=|\"|\[|\>|\<', line)
            for linepart in lineparts:
                linuxpaths = re.findall(RE_LINUX_PATH, linepart)
                # --- Change 1: exclude safe Linux system paths ---
                paths = [
                    p for p in linuxpaths
                    if p not in tags
                    and p not in IGNORE_PATHS
                    and not is_safe_linux_path(p)
                ]
                for path in paths:
                    redacted_path = apply_custom_rules_to_substring(path, crlist, registry)
                    token = registry.redact(redacted_path, 'redacted_path')
                    line = line.replace(path, f'/{token}')
    return line


def gzfile(path):
    with open(path, 'rb') as f_in:
        with gzip.open('%s.gz' % path, 'wb') as f_out:
            shutil.copyfileobj(f_in, f_out)

def targzdirectory(path, name):
    with tarfile.open(name, "w:gz") as tarhandle:
        for root, dirs, files in os.walk(path):
            for f in files:
                fullname = os.path.join(root, f)
                relname = fullname.replace(path, '')
                tarhandle.add(os.path.join(root, f), arcname=relname)

def process_file(root, filename, crlist, parallel=True, max_workers=None):
    filepath = os.path.join(root, filename)
    filename_short, file_extension = os.path.splitext(filename)
    # rename .tgz to .tar.gz
    if file_extension.lower() == '.tgz':
        newfilename = '%s.tar.gz' % filename_short
        newfilepath = os.path.join(root, newfilename)
        os.replace(filepath, newfilepath)
        filename = newfilename
        filepath = os.path.join(root, filename)
        filename_short, file_extension = os.path.splitext(filename)

    if file_extension.lower() == '.gz':
        # unzip gz file
        unzippedfile = os.path.join(root, filename_short)
        with gzip.open(filepath, 'rb') as f_in:
            with open(unzippedfile, 'wb') as f_out:
                shutil.copyfileobj(f_in, f_out)
        os.remove(filepath)
        unzipped_filename_short, unzipped_file_extension = os.path.splitext(unzippedfile)

        if unzipped_file_extension.lower() == '.tar':
            # untar tar file
            untarred_folder = unzippedfile[0:-4]
            tar = tarfile.open(unzippedfile, 'r')
            tar.extractall(untarred_folder)
            tar.close()
            os.remove(unzippedfile)
            walkdir(untarred_folder, crlist, parallel=parallel, max_workers=max_workers)
            # re-tar and re-zip
            targzdirectory(untarred_folder, filepath)
            shutil.rmtree(untarred_folder)
        else:
            obfuscatefile(root, unzippedfile, crlist)
            # re-zip
            gzfile(unzippedfile)
            os.remove(unzippedfile)
    elif file_extension.lower() == '.tar':
        # untar tar file
        untarred_folder = filepath[0:-4]
        tar = tarfile.open(filepath, 'r')
        tar.extractall(untarred_folder)
        tar.close()
        os.remove(filepath)
        walkdir(untarred_folder, crlist, parallel=parallel, max_workers=max_workers)
        targzdirectory(untarred_folder, '%s.gz' % filepath)
        shutil.rmtree(untarred_folder)
    elif file_extension.lower() == 'zip':
        print('*** unhandled zip file *** %s' % filepath)
    else:
        obfuscatefile(root, filepath, crlist)

def redact_dirname(name: str, crlist, registry: 'RedactionRegistry') -> str:
    """Apply custom redaction rules to a single directory name component.

    Only the bare name (not the full path) is processed so that path separators
    are not mangled.  Returns the (possibly modified) name.
    """
    return redact_filename(name, crlist, registry)


def walkdir(thispath, crlist, parallel=False, max_workers=None):
    # Collect all directory paths up front so we can rename them bottom-up
    # after all file processing is done (renaming top-down would break the
    # paths that os.walk still needs to visit).
    all_dirs = []

    tasks = []
    if parallel:
        with ProcessPoolExecutor(max_workers=max_workers) as executor:
            for root, dirs, files in os.walk(thispath, topdown=True):
                all_dirs.append((root, sorted(dirs[:])))
                for filename in sorted(files):
                    future = executor.submit(process_file, root, filename, crlist)
                    future.add_done_callback(task_done)
                    tasks.append(future)
        # Wait for all file tasks to complete before renaming directories
        for future in tasks:
            try:
                future.result()
            except Exception:
                pass
    else:
        for root, dirs, files in os.walk(thispath, topdown=True):
            all_dirs.append((root, sorted(dirs[:])))
            for filename in sorted(files):
                process_file(root, filename, crlist, parallel=False, max_workers=max_workers)

    # Rename directories bottom-up so child renames do not invalidate parent paths.
    # A shared registry per walkdir call keeps tokens stable across the whole tree.
    if crlist:
        dir_registry = RedactionRegistry()
        # Reverse so deepest directories come first
        for root, dirnames in reversed(all_dirs):
            for dirname in dirnames:
                new_dirname = redact_dirname(dirname, crlist, dir_registry)
                if new_dirname != dirname:
                    old_path = os.path.join(root, dirname)
                    new_path = os.path.join(root, new_dirname)
                    if os.path.exists(old_path):
                        print(f'  dir redacted: {old_path} -> {new_path}', flush=True)
                        os.replace(old_path, new_path)

def task_done(future):
    try:
        result = future.result()
    except Exception as e:
        print(f"Task generated an exception: {e}")

def get_size(start_path = '.'):
    total_size = 0
    for dirpath, dirnames, filenames in os.walk(start_path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            # skip if it is symbolic link
            if not os.path.islink(fp):
                total_size += os.path.getsize(fp)

    return total_size

if __name__ == '__main__':

    # command line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument('-l', '--logpath', type=str, required=True)
    parser.add_argument('-w', '--workers', type=int, default=2, help='Number of worker processes')
    parser.add_argument('-p', '--parallel', action='store_true', help='Run in parallel using ProcessPoolExecutor')
    parser.add_argument('-f', '--freespacemultiplier', type=int, default=3, help='require free space multiple')
    parser.add_argument('-cr', '--customrules', type=str, default=None, help='custom rules file')
    parser.add_argument('-o', '--outpath', type=str, default=None)
    args = parser.parse_args()
    
    logpath = args.logpath
    freespacemultiplier = args.freespacemultiplier
    customrules = args.customrules
    outpath = args.outpath
    if outpath is None:
        outpath = logpath

    GiB = 1024 * 1024 * 1024

    if customrules is not None:
        if os.path.exists(customrules):
            crjson = open(customrules, 'r')
            crs = json.load(crjson)
            crlist = []
            for rule in crs:
                pattern = rule['pattern']
                # Compile with DOTALL so patterns can span newlines (multi-line support)
                regex = re.compile(pattern, re.DOTALL)
                rule['regex'] = regex
                crlist.append(rule)

    if os.path.isdir(logpath) is False:
        print('logpath %s is not found' % logpath)
        exit(1)
    logfoldersize = get_size(logpath)
    freespace = shutil.disk_usage(logpath).free
    if freespace < (logfoldersize * freespacemultiplier):
        print('log folder path size is %s GiB' % round(logfoldersize / GiB, 2))
        print('log folder free space is %s GiB' % round(freespace / GiB, 2))
        print('at least %s GiB free space is recommended to proceed' % round(logfoldersize * freespacemultiplier / GiB, 2))
        exit()
    start_time = time.time()
    walkdir(logpath, crlist, parallel=True, max_workers=args.workers)
    end_time = time.time()
    
    # Calculate and print the execution time
    execution_time = end_time - start_time
    print(f"\nExecution time: {execution_time} seconds\n")
    