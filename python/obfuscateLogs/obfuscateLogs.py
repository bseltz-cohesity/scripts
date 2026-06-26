#!/usr/bin/env python
"""obfuscate logs"""

VERSION = '2026-06-26'

import os
import gzip
import shutil
import re
import json
import codecs
import tarfile
from concurrent.futures import ProcessPoolExecutor
import multiprocessing
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
    # NetBackup (Veritas) installation paths — not sensitive, should not be redacted
    '/usr/openv',
    '/usr/openv/bin',
    '/usr/openv/lib',
    '/usr/openv/netbackup',
    '/usr/openv/netbackup/bin',
    '/usr/openv/netbackup/bin/admincmd',
    '/usr/openv/netbackup/bin/goodies',
    '/usr/openv/netbackup/logs',
    '/usr/openv/netbackup/db',
    '/usr/openv/netbackup/ext',
    '/usr/openv/netbackup/help',
    '/usr/openv/netbackup/online_help',
    '/usr/openv/volmgr',
    '/usr/openv/volmgr/bin',
    '/usr/openv/var',
    '/usr/openv/var/global',
])

# Regex to quickly test whether a path starts with a known safe prefix.
# We compile a single pattern for speed.
_SAFE_PREFIX_RE = re.compile(
    r'^(?:' +
    '|'.join(re.escape(p) for p in sorted(SAFE_LINUX_PATHS, key=len, reverse=True)) +
    r')(?:[/\s,;"\']|$)'
)

# ---------------------------------------------------------------------------
# User-defined safe paths (loaded at runtime via --safepaths)
# ---------------------------------------------------------------------------
_user_safe_paths: set = set()
_user_safe_prefix_re = None   # compiled when paths are loaded


def load_user_safe_paths(filepath: str) -> None:
    """Load additional safe paths from a plain-text file (one path per line).

    Lines that are blank or start with '#' are ignored.  The paths are added
    to the global user safe-path set and a prefix regex is compiled so that
    any sub-path under a listed entry is also protected.
    """
    global _user_safe_paths, _user_safe_prefix_re
    paths = set()
    with open(filepath, 'r') as fh:
        for raw in fh:
            entry = raw.strip()
            if entry and not entry.startswith('#'):
                paths.add(entry)
    _user_safe_paths = paths
    if paths:
        _user_safe_prefix_re = re.compile(
            r'^(?:' +
            '|'.join(re.escape(p) for p in sorted(paths, key=len, reverse=True)) +
            r')(?:[/\s,;"\']|$)'
        )


def _worker_initializer(safepaths_file) -> None:
    """Initializer for ProcessPoolExecutor workers.

    Each spawned worker process imports the module fresh and has empty globals.
    Re-load user safe paths here so is_safe_linux_path() works correctly in
    every worker, not just the main process.
    """
    if safepaths_file:
        load_user_safe_paths(safepaths_file)


# ---------------------------------------------------------------------------
# NetBackup version-number exclusion
# ---------------------------------------------------------------------------
# NetBackup version strings (e.g. 10.3.0.1, 9.1.0.1) look exactly like IPv4
# addresses and would be incorrectly redacted by the IPv4 custom rule.
#
# Detection strategy (two-tier):
#   1. Keyword context: if an NBU-related keyword (NetBackup, nbu, version,
#      etc.) appears on the same line, any structurally valid NBU version is
#      preserved regardless of its numeric value.
#   2. No-keyword structural check: the value must match the narrow pattern
#      MAJOR.MINOR.0.BUILD where MAJOR is 7-10 and MINOR >= 1.  This covers
#      the common annotation-free case (e.g. a bare "10.3.0.1" in a path)
#      while still redacting genuinely ambiguous values like 10.0.0.1 that
#      are indistinguishable from a private gateway IP without context.

# Structural pattern: major 7-10, minor 0-9, patch 0-9, build 0-99
RE_NBU_STRUCTURAL = re.compile(
    r'^(?:[7-9]|10)\.[0-9]\.[0-9]\.(?:[0-9]|[1-9][0-9])$'
)

# Keywords that indicate a dotted-quad is a product version, not an IP
RE_NBU_KEYWORDS = re.compile(
    r'(?i)\b(?:netbackup|veritas|openv|nbu|bpcd|bprd|nbpem|nbjm|nbim'
    r'|version|release|ver|build|installed|upgrade|patch)\b'
)

# Types of custom-rule matches that could incorrectly consume version numbers.
# Add more type prefixes here if new IP-like rules are introduced.
_IP_LIKE_RULE_TYPES = frozenset([
    'redacted_ipv4_',
    'redacted_ip_',
    'redacted_ipv4',
])


def is_nbu_version(value: str, context: str = '') -> bool:
    """Return True if *value* looks like a NetBackup version number.

    *context* is the surrounding text (e.g. the full log line).  When it
    contains an NBU-related keyword the structural check is used as-is.
    Without a keyword, the minor version must be >= 1 and the patch octet
    must be 0 — this rejects common IPs like 10.0.0.1 and 8.8.8.8 while
    still preserving obvious version strings like 10.3.0.1 and 9.1.0.1.
    """
    value = value.strip()
    if not RE_NBU_STRUCTURAL.match(value):
        return False
    if context and RE_NBU_KEYWORDS.search(context):
        return True
    parts = value.split('.')
    return int(parts[2]) == 0 and int(parts[1]) >= 1


def is_safe_linux_path(path: str) -> bool:
    """Return True if *path* is a standard, non-sensitive Linux system path."""
    stripped = path.strip()
    if stripped in SAFE_LINUX_PATHS:
        return True
    if _SAFE_PREFIX_RE.match(stripped):
        return True
    # Check user-supplied safe paths (--safepaths)
    if _user_safe_paths:
        if stripped in _user_safe_paths:
            return True
        if _user_safe_prefix_re and _user_safe_prefix_re.match(stripped):
            return True
    return False


def mask_dates(text: str) -> str:
    """Replace '/' inside slash-separated dates with '_' so that RE_LINUX_PATH
    does not start a path match inside a date like 01/30/2026 or 01/30/26.

    The returned string is only used for *finding* path candidates; all actual
    replacements are performed on the original line, so date text is never
    altered in the output.
    """
    return RE_DATE_SLASH.sub(lambda m: m.group().replace('/', '_'), text)


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
# Full slash-separated date pattern (MM/DD/YYYY or MM/DD/YY).  Used to mask
# date slashes before RE_LINUX_PATH runs so that the '/' inside a date is not
# mistaken for a path separator.
RE_DATE_SLASH = re.compile(r'\b\d{1,2}/\d{1,2}/(?:\d{4}|\d{2})\b')

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


class LockedRedactionRegistry:
    """Process-safe redaction registry for parallel mode.

    Backed by multiprocessing.Manager proxy objects so that token assignments
    are shared — and consistent — across all worker processes in a run.

    Uses a flat key format '<prefix>\\x00<original>' to avoid nested-dict
    mutation issues with Manager proxies.  A manager Lock serialises writes
    so only one process can mint a new token at a time.

    Performance: each worker process keeps a plain-dict local cache.  The
    vast majority of redact() calls are repeated lookups for the same handful
    of hostnames/paths in a log file, so they hit the local cache without any
    IPC.  IPC only occurs on the first time a worker encounters a given string
    (cache miss → one Manager.dict.get), and locking only occurs when a brand-
    new token actually needs to be minted.
    """

    def __init__(self, manager):
        # Shared state — accessed via IPC from every worker process.
        # Flat dict: '<prefix>\x00<original>' -> token string
        self._maps = manager.dict()
        # Per-prefix counters: prefix -> int
        self._counters = manager.dict()
        self._lock = manager.Lock()
        # Per-process local cache — plain dict, zero IPC cost.
        # Tokens are immutable once assigned, so the cache is always valid.
        self._local_cache: dict = {}

    def redact(self, original: str, prefix: str) -> str:
        """Return the stable redaction token for *original* under *prefix*."""
        key = f'{prefix}\x00{original}'

        # 1. Local cache — no IPC; hits the vast majority of calls.
        token = self._local_cache.get(key)
        if token is not None:
            return token

        # 2. Shared dict read — one IPC call; no lock needed for a read.
        token = self._maps.get(key)
        if token is not None:
            self._local_cache[key] = token
            return token

        # 3. New token — acquire lock, re-check, then mint.
        with self._lock:
            token = self._maps.get(key)
            if token is not None:
                self._local_cache[key] = token
                return token
            count = self._counters.get(prefix, 0) + 1
            self._counters[prefix] = count
            token = f'{prefix}_{count:03d}'
            self._maps[key] = token
            self._local_cache[key] = token
            return token


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
                        if prefix in _IP_LIKE_RULE_TYPES and is_nbu_version(submatch, new_name):
                            continue
                        token = registry.redact(submatch, prefix)
                        new_name = new_name.replace(submatch, token)
            else:
                if prefix in _IP_LIKE_RULE_TYPES and is_nbu_version(match, new_name):
                    continue
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
                        if prefix in _IP_LIKE_RULE_TYPES and is_nbu_version(submatch, value):
                            continue
                        token = registry.redact(submatch, prefix)
                        value = value.replace(submatch, token)
            else:
                if prefix in _IP_LIKE_RULE_TYPES and is_nbu_version(match, value):
                    continue
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
                        if prefix in _IP_LIKE_RULE_TYPES and is_nbu_version(submatch, joined):
                            continue
                        token = registry.redact(submatch, prefix)
                        joined = joined.replace(submatch, token)
            else:
                if prefix in _IP_LIKE_RULE_TYPES and is_nbu_version(match, joined):
                    continue
                token = registry.redact(match, prefix)
                joined = joined.replace(match, token)

    # Re-split on newlines after redaction.
    #
    # We cannot use the original line lengths to slice up `joined` because
    # redaction tokens are a different length from the text they replaced —
    # any substitution shifts every subsequent offset, causing lines to be
    # truncated, merged, or lose their newline terminator entirely.
    #
    # Instead, split `joined` on newlines and reattach the correct terminator
    # to each piece.  `str.split('\n')` always produces exactly one more
    # element than the number of newline characters, so this round-trips
    # cleanly for both LF and CRLF content.
    parts = joined.split('\n')
    result = []
    for i, part in enumerate(parts):
        if i < len(parts) - 1:
            # Determine whether the original used CRLF or LF.
            # Look at the corresponding original line if available; fall back
            # to plain LF.
            if i < len(lines) and lines[i].endswith('\r\n'):
                result.append(part.rstrip('\r') + '\r\n')
            else:
                result.append(part + '\n')
        else:
            # Last segment: only append if non-empty (handles files that end
            # with a newline, where split produces a trailing empty string).
            if part:
                result.append(part)
    return result


# ---------------------------------------------------------------------------
# Core file obfuscation
# ---------------------------------------------------------------------------

def obfuscatefile(root, filepath, crlist, registry=None):
    filename = os.path.basename(filepath)
    print(filepath, flush=True)
    if filename.startswith('redacted_'):
        return

    # Skip symlinks whose target does not exist (broken symlinks) and any path
    # that is not a regular file.  os.path.isfile() returns False for both.
    if not os.path.isfile(filepath):
        print(f'  skipping (not a regular file or broken symlink): {filepath}', flush=True)
        return

    # Use the shared registry when provided; fall back to a local one otherwise.
    if registry is None:
        registry = RedactionRegistry()

    # --- Change 3: Redact the filename itself ---
    new_filename = redact_filename(filename, crlist, registry)
    if new_filename != filename:
        new_filepath = os.path.join(root, new_filename)
        os.replace(filepath, new_filepath)
        filepath = new_filepath
        filename = new_filename
        print(f'  filename redacted -> {filename}', flush=True)

    # Skip binary files — still rename them if the filename needed redacting,
    # but do not attempt to scan or rewrite their contents.  Binary detection
    # reads the first 8 KB and looks for null bytes, which are essentially
    # absent from text/log files but reliably present in binary formats.
    BINARY_DETECT_BYTES = 8192
    with open(filepath, 'rb') as _probe:
        if b'\x00' in _probe.read(BINARY_DETECT_BYTES):
            print(f'  skipping binary file: {filepath}', flush=True)
            return

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
                            securefile = f'path={raw_original},'
                            if redacted_original != raw_original:
                                # A custom rule already tokenised sensitive content within the
                                # path (e.g. a hostname).  Surface those tokens directly so the
                                # same hostname gets the same code whether it appears standalone
                                # or embedded in a path.
                                line = line.replace(securefile, f'path={redacted_original},')
                            else:
                                token = registry.redact(redacted_original, 'redacted_path')
                                line = line.replace(securefile, f'path={token},')
            if 'entry=' in line:
                lineparts = line.split('entry=')
                if len(lineparts) > 0:
                    lineparts2 = lineparts[1].split(' in dir')
                    if len(lineparts2) > 0:
                        raw_original = lineparts2[0]
                        if not is_safe_linux_path(raw_original):
                            redacted_original = apply_custom_rules_to_substring(raw_original, crlist, registry)
                            securefile = f'entry={raw_original}'
                            if redacted_original != raw_original:
                                line = line.replace(securefile, f'entry={redacted_original}')
                            else:
                                token = registry.redact(redacted_original, 'redacted_entry')
                                line = line.replace(securefile, f'entry={token}')
            if 'dir_sync_tx2_op.cc' in line:
                lineparts = line.split('Looking up ')
                if len(lineparts) > 1:
                    lineparts2 = lineparts[1].split(' in dir')
                    if len(lineparts2) > 1:
                        raw_original = lineparts2[0]
                        if not is_safe_linux_path(raw_original):
                            redacted_original = apply_custom_rules_to_substring(raw_original, crlist, registry)
                            if redacted_original != raw_original:
                                line = line.replace(f'Looking up {raw_original}', f'Looking up {redacted_original}')
                            else:
                                token = registry.redact(redacted_original, 'redacted_path')
                                line = line.replace(f'Looking up {raw_original}', f'Looking up {token}')
                lineparts = line.split('for entry=')
                if len(lineparts) > 1:
                    lineparts2 = lineparts[1].split(' in dir=')
                    if len(lineparts2) > 1:
                        raw_original = lineparts2[0]
                        if not is_safe_linux_path(raw_original):
                            redacted_original = apply_custom_rules_to_substring(raw_original, crlist, registry)
                            if redacted_original != raw_original:
                                line = line.replace(f'entry={raw_original}', f'entry={redacted_original}')
                            else:
                                token = registry.redact(redacted_original, 'redacted_entry')
                                line = line.replace(f'entry={raw_original}', f'entry={token}')
            tags = ''.join(re.findall(RE_TAGS, line))
            lineparts = re.split(RE_SPLIT_LINE, line)
            for linepart in lineparts:
                windowspaths = re.findall(RE_WIN_PATH, linepart)
                paths = [p for p in windowspaths if p not in tags and p not in [i for i in IGNORE_PATHS]]
                for path in paths:
                    redacted_path = apply_custom_rules_to_substring(path, crlist, registry)
                    if redacted_path != path:
                        line = line.replace(path, redacted_path)
                    else:
                        token = registry.redact(redacted_path, 'redacted_path')
                        line = line.replace(path, f'\\{token}')
            lineparts = re.split('=|\"|\[|\>|\<', line)
            for linepart in lineparts:
                # Mask date slashes before path detection so that a date like
                # 01/30/2026 is not parsed as a Linux path fragment (/30/2026).
                # Path strings found in the masked copy are identical to those
                # in the original (only date-internal slashes differ), so they
                # can be used directly for line.replace() below.
                linuxpaths = re.findall(RE_LINUX_PATH, mask_dates(linepart))
                # --- Change 1: exclude safe Linux system paths ---
                paths = [
                    p for p in linuxpaths
                    if p not in tags
                    and p not in IGNORE_PATHS
                    and not is_safe_linux_path(p)
                ]
                for path in paths:
                    redacted_path = apply_custom_rules_to_substring(path, crlist, registry)
                    if redacted_path != path:
                        line = line.replace(path, redacted_path)
                    else:
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

def redact_archive_name(root, filename, crlist, registry=None):
    """Redact sensitive substrings from an archive filename (base name only).

    Uses the shared registry when provided so archive filename tokens are
    consistent with tokens assigned inside file content.  Falls back to a
    local registry if none is supplied.  Returns the new full filepath.
    If the name is unchanged the original filepath is returned without any
    filesystem operation.
    """
    if not crlist:
        return os.path.join(root, filename)
    if registry is None:
        registry = RedactionRegistry()
    new_filename = redact_filename(filename, crlist, registry)
    if new_filename == filename:
        return os.path.join(root, filename)
    new_filepath = os.path.join(root, new_filename)
    old_filepath = os.path.join(root, filename)
    if os.path.exists(old_filepath):
        print(f'  archive renamed: {filename} -> {new_filename}', flush=True)
        os.replace(old_filepath, new_filepath)
    return new_filepath


def process_file(root, filename, crlist, parallel=True, max_workers=None, registry=None):
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
        try:
            with gzip.open(filepath, 'rb') as f_in:
                with open(unzippedfile, 'wb') as f_out:
                    shutil.copyfileobj(f_in, f_out)
        except (gzip.BadGzipFile, EOFError, OSError) as e:
            print(f'  skipping (failed to decompress): {filepath}: {e}', flush=True)
            # Remove the partial output file if it was created
            if os.path.exists(unzippedfile):
                os.remove(unzippedfile)
            return
        os.remove(filepath)
        unzipped_filename_short, unzipped_file_extension = os.path.splitext(unzippedfile)

        if unzipped_file_extension.lower() == '.tar':
            # untar tar file
            untarred_folder = unzippedfile[0:-4]
            try:
                tar = tarfile.open(unzippedfile, 'r')
                tar.extractall(untarred_folder)
                tar.close()
            except (tarfile.TarError, EOFError, OSError) as e:
                print(f'  skipping (failed to extract): {unzippedfile}: {e}', flush=True)
                if os.path.exists(unzippedfile):
                    os.remove(unzippedfile)
                if os.path.exists(untarred_folder):
                    shutil.rmtree(untarred_folder)
                return
            os.remove(unzippedfile)
            if os.path.isdir(untarred_folder):
                walkdir(untarred_folder, crlist, parallel=parallel, max_workers=max_workers, registry=registry)
                # re-tar and re-zip, then redact the output archive filename
                targzdirectory(untarred_folder, filepath)
                shutil.rmtree(untarred_folder)
                redact_archive_name(root, filename, crlist, registry=registry)
            else:
                print(f'  skipping (archive extracted no files): {filepath}', flush=True)
        else:
            obfuscatefile(root, unzippedfile, crlist, registry=registry)
            # re-zip then redact the output .gz filename
            gzfile(unzippedfile)
            os.remove(unzippedfile)
            gz_filename = os.path.basename(unzippedfile) + '.gz'
            redact_archive_name(root, gz_filename, crlist, registry=registry)
    elif file_extension.lower() == '.tar':
        # untar tar file
        untarred_folder = filepath[0:-4]
        try:
            tar = tarfile.open(filepath, 'r')
            tar.extractall(untarred_folder)
            tar.close()
        except (tarfile.TarError, EOFError, OSError) as e:
            print(f'  skipping (failed to extract): {filepath}: {e}', flush=True)
            if os.path.exists(untarred_folder):
                shutil.rmtree(untarred_folder)
            return
        os.remove(filepath)
        if os.path.isdir(untarred_folder):
            walkdir(untarred_folder, crlist, parallel=parallel, max_workers=max_workers, registry=registry)
            # re-tar and re-zip, then redact the output archive filename
            out_gz = '%s.gz' % filepath
            targzdirectory(untarred_folder, out_gz)
            shutil.rmtree(untarred_folder)
            redact_archive_name(root, os.path.basename(out_gz), crlist, registry=registry)
        else:
            print(f'  skipping (archive extracted no files): {filepath}', flush=True)
    elif file_extension.lower() == 'zip':
        print('*** unhandled zip file *** %s' % filepath)
    else:
        obfuscatefile(root, filepath, crlist, registry=registry)

def redact_dirname(name: str, crlist, registry: 'RedactionRegistry') -> str:
    """Apply custom redaction rules to a single directory name component.

    Only the bare name (not the full path) is processed so that path separators
    are not mangled.  Returns the (possibly modified) name.
    """
    return redact_filename(name, crlist, registry)


def walkdir(thispath, crlist, parallel=False, max_workers=None, registry=None, safepaths_file=None):
    # Collect all directory paths up front so we can rename them bottom-up
    # after all file processing is done (renaming top-down would break the
    # paths that os.walk still needs to visit).
    all_dirs = []

    tasks = []
    if parallel:
        with ProcessPoolExecutor(max_workers=max_workers,
                                  initializer=_worker_initializer,
                                  initargs=(safepaths_file,)) as executor:
            for root, dirs, files in os.walk(thispath, topdown=True):
                all_dirs.append((root, sorted(dirs[:])))
                for filename in sorted(files):
                    future = executor.submit(process_file, root, filename, crlist,
                                             registry=registry)
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
                process_file(root, filename, crlist, parallel=False,
                             max_workers=max_workers, registry=registry)

    # Rename directories bottom-up so child renames do not invalidate parent paths.
    # Uses the shared registry so directory-name tokens are consistent with the
    # tokens assigned inside file content.
    if crlist and registry is not None:
        # Reverse so deepest directories come first
        for root, dirnames in reversed(all_dirs):
            for dirname in dirnames:
                new_dirname = redact_dirname(dirname, crlist, registry)
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
    parser.add_argument('-v', '--version', action='version', version=f'%(prog)s {VERSION}')
    parser.add_argument('-l', '--logpath', type=str, required=True)
    parser.add_argument('-w', '--workers', type=int, default=2, help='Number of worker processes')
    parser.add_argument('-p', '--parallel', action='store_true', help='Run in parallel using ProcessPoolExecutor')
    parser.add_argument('-f', '--freespacemultiplier', type=int, default=3, help='require free space multiple')
    parser.add_argument('-cr', '--customrules', type=str, default=None, help='custom rules file')
    parser.add_argument('-sp', '--safepaths', type=str, default=None,
                        help='text file of additional paths to never redact (one per line; # comments supported)')
    parser.add_argument('-o', '--outpath', type=str, default=None)
    args = parser.parse_args()
    
    logpath = args.logpath
    freespacemultiplier = args.freespacemultiplier
    customrules = args.customrules
    outpath = args.outpath
    if outpath is None:
        outpath = logpath

    GiB = 1024 * 1024 * 1024

    if args.safepaths is not None:
        if os.path.exists(args.safepaths):
            load_user_safe_paths(args.safepaths)
        else:
            print(f'safepaths file not found: {args.safepaths}')
            exit(1)

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
    # Build a shared registry so that the same value always receives the same
    # redaction token across every file processed in this run.
    # Parallel mode uses a LockedRedactionRegistry backed by a Manager server
    # so worker processes can safely share token state across process boundaries.
    args.parallel = True
    if args.parallel:
        _manager = multiprocessing.Manager()
        registry = LockedRedactionRegistry(_manager)
    else:
        registry = RedactionRegistry()

    start_time = time.time()
    walkdir(logpath, crlist, parallel=args.parallel, max_workers=args.workers,
            registry=registry, safepaths_file=args.safepaths)
    end_time = time.time()
    
    # Calculate and print the execution time
    execution_time = end_time - start_time
    print(f"\nExecution time: {execution_time} seconds\n")
