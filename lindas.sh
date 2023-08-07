#!/bin/bash

# Inspired by linpeas by Carlos Polop

###########################################
#---------------) Colors (----------------#
###########################################

C=$(printf '\033')
RED="${C}[1;31m"
SED_RED="${C}[1;31m&${C}[0m"
GREEN="${C}[1;32m"
SED_GREEN="${C}[1;32m&${C}[0m"
YELLOW="${C}[1;33m"
SED_YELLOW="${C}[1;33m&${C}[0m"
RED_YELLOW="${C}[1;31;103m"
SED_RED_YELLOW="${C}[1;31;103m&${C}[0m"
BLUE="${C}[1;34m"
SED_BLUE="${C}[1;34m&${C}[0m"
ITALIC_BLUE="${C}[1;34m${C}[3m"
LIGHT_MAGENTA="${C}[1;95m"
SED_LIGHT_MAGENTA="${C}[1;95m&${C}[0m"
LIGHT_CYAN="${C}[1;96m"
SED_LIGHT_CYAN="${C}[1;96m&${C}[0m"
LG="${C}[1;37m" #LightGray
SED_LG="${C}[1;37m&${C}[0m"
DG="${C}[1;90m" #DarkGray
SED_DG="${C}[1;90m&${C}[0m"
NC="${C}[0m"
UNDERLINED="${C}[5m"
ITALIC="${C}[3m"



printf ${BLUE}"Linux Defense Awesome Script"${NC}

# see who is currently logged in

who

# look at sshd config. who can log in?

# print authorized keys

for user in $(ls /home); do
    if [ -f /home/$user/.ssh/authorized_keys ]; then
        echo "Authorized keys for $user:"
        cat /home/$user/.ssh/authorized_keys
    fi
done

if [ -f /root/.ssh/authorized_keys ]; then
    echo "Authorized keys for root:"
    cat /root/.ssh/authorized_keys
fi

# look for all users with a shell in /etc/passwd 

cat /etc/passwd | grep "sh$"

# print sudoers file

# print files modified in the last hour
find / -xdev -mmin -60 -ls 2> /dev/null


# print path (and look for unexpected paths) and maybe for bins in those paths

echo "$PATH"


# DOES NOT WORK FOR DEBIAN BASED SYSTEMS YET!!
is_managed_by_package_manager() {
    local file="$1"
    if command -v dpkg-query >/dev/null 2>&1; then
    	dpkg -S "$(readlink -fn "$(which "$file")")" >/dev/null 2>&1
    elif command -v rpm >/dev/null 2>&1; then
        rpm -qf "$file" >/dev/null 2>&1
    else
        return 1
    fi
}

# Split the PATH into an array of directories
IFS=':' read -ra DIRS <<< "$PATH"

# Iterate over each directory in the PATH
for dir in "${DIRS[@]}"; do
    # Check if the directory exists and is readable
    if [[ -d "$dir" && -r "$dir" ]]; then
        # Iterate over each file in the directory
        for file in "$dir"/*; do
            # Check if the file is an executable regular file
            if [[ -f "$file" && -x "$file" ]]; then
                # Check if the file is managed by a package manager
                if ! is_managed_by_package_manager "$file"; then
                    echo "Unmanaged executable: $file"
                fi
            fi
        done
    fi
done

# dpkg -V or rpm -Va

if command -v /usr/bin/dpkg >/dev/null 2>&1; then
    echo "Checking package integrity using dpkg -V"
    /usr/bin/dpkg -V
elif command -v /usr/bin/rpm >/dev/null 2>&1; then
    echo "Checking package integrity using rpm -Va"
    /usr/bin/rpm -Va
elif command -v /usr/bin/pacman >/dev/null 2>&1; then
    echo "Checking package integrity using pacman -Qkk"
    /usr/bin/pacman -Qkk
elif command -v /usr/bin/zypper >/dev/null 2>&1; then
    echo "Checking package integrity using zypper verify"
    /usr/bin/zypper verify
elif command -v /usr/bin/emerge >/dev/null 2>&1; then
    echo "Checking package integrity using emerge -K @world"
    /usr/bin/emerge -K @world
else
    echo "Error: No supported package manager found"
fi


# print suid binaries

SAFE_SUID_BINARIES=(
    "/usr/lib/polkit-1/polkit-agent-helper-1"
    "/usr/lib/dbus-1.0/dbus-daemon-launch-helper"
    "/usr/lib/openssh/ssh-keysign"
    "/usr/libexec/cockpit-session"
	"/usr/bin/mount"
	"/usr/bin/umount"
	"/usr/bin/chage"
	"/usr/bin/gpasswd"
	"/usr/bin/newgrp"
	"/usr/bin/su"
	"/usr/bin/pkexec"
	"/usr/bin/sudo"
	"/usr/bin/passwd"
	"/usr/bin/crontab"
	"/usr/sbin/grub2-set-bootflag"
	"/usr/sbin/pam_timestamp_check"
	"/usr/sbin/unix_chkpwd"
	"/usr/libexec/openssh/ssh-keysign"
	"/usr/bin/chsh"
	"/usr/bin/chfn"
	"/usr/bin/chage"
	"/usr/sbin/mount.nfs"

)

# Find all SUID binaries on the system
SUID_BINARIES=$(find / -perm -u=s -type f 2>/dev/null)

# Iterate over each SUID binary
while IFS= read -r binary; do
    # Check if the binary is in the list of known safe SUID binaries
    if [[ " ${SAFE_SUID_BINARIES[@]} " =~ " ${binary} " ]]; then
        echo "Safe SUID binary: $binary"
    else
        echo "Suspicious SUID binary: $binary"
    fi
done <<< "$SUID_BINARIES"

# print suspicious binaries (how do we do this?)

# print all services

find /etc/systemd/system -name "*.service" -exec cat {} + | grep -E "ExecStart|Description" | sed "s/Description/\nDescription/g" | cut -d "=" -f2 


# look for orphaned filed


# Find all files and directories with no user
NOUSER=$(find / \( -type f -o -type d \) -nouser 2>/dev/null)

# Find all files and directories with no group
NOGROUP=$(find / \( -type f -o -type d \) -nogroup 2>/dev/null)

# Combine the lists of files and directories with no user or no group
ORPHANED=$(echo -e "$NOUSER\n$NOGROUP" | sort | uniq)

# Check if there are any orphaned files or directories
if [[ -z "$ORPHANED" ]]; then
    echo "None!"
else
    # Print the list of orphaned files and directories
    echo "Orphaned files and directories:"
    while IFS= read -r file; do
        ls -ld "$file"
    done <<< "$ORPHANED"
fi

# look for world writable files

# install useful things

## ufw, opensnitch, rkhunter, lynis, chkrootkit, clamav, aide, logwatch, logcheck, tripwire, fail2ban, 

# look for files named with dots and spaces (used to camoflage files)


##  DOESNT WORK
find / -name "..." 2>/dev/null
find / -name ".. " 2>/dev/null
find / -name ". " 2>/dev/null
find / -name " " 2>/dev/null

# look for processes running out of or accessing files that have been unlinked. 

# look for rootkits

# look for interfaces in promiscuous mode

ip link | grep PROMISC

# look at listening processes

# look for all cronjobs

# back configs up?

# look up immutable and append-only files

# install updates && upgrades

# Check which package manager is available
if command -v apt-get >/dev/null 2>&1; then
    # Debian/Ubuntu-based distributions
    echo "Updating and upgrading using apt-get"
    sudo apt-get update
    sudo apt-get dist-upgrade -y
elif command -v yum >/dev/null 2>&1; then
    # Red Hat-based distributions
    echo "Updating and upgrading using yum"
    sudo yum update -y
elif command -v zypper >/dev/null 2>&1; then
    # SUSE-based distributions
    echo "Updating and upgrading using zypper"
    sudo zypper refresh
    sudo zypper update -y
elif command -v pacman >/dev/null 2>&1; then
    # Arch-based distributions
    echo "Updating and upgrading using pacman"
    sudo pacman -Syu --noconfirm
else
    echo "Error: No supported package manager found"
fi

### remember to reinstall services

# find processes running from uncommon directories

# set up auditd

# set up siem?