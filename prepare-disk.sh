#!/usr/bin/env bash

source ./utilities.sh

install_disk=$1
ram=$(($(free -m | awk '/Mem:/ {print $2}') + 4598))

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

if ! [ -e "$install_disk" ]; then
  echo "Selected disk not valid"
  exit
fi

password=$(get_passwd)

# create gpt partition table
parted "$install_disk" mklabel gpt >/dev/null 2>&1
# create boot partition
parted "$install_disk" mkpart primary fat32 2Mib 502Mib >/dev/null 2>&1
# create pop os recovery partition
parted "$install_disk" mkpart primary fat32 502MiB 4598MiB >/dev/null 2>&1
# create swap partition
parted "$install_disk" mkpart primary fat32 4598MiB $ram"MiB" >/dev/null 2>&1
# create main partition
parted "$install_disk" mkpart primary $ram"MiB" 100% >/dev/null 2>&1

# set flags and names
parted "$install_disk" name 1 EFI >/dev/null 2>&1
parted "$install_disk" set 1 esp on >/dev/null 2>&1
parted "$install_disk" name 2 recovery >/dev/null 2>&1
parted "$install_disk" name 3 SWAP >/dev/null 2>&1
parted "$install_disk" set 3 swap on >/dev/null 2>&1
parted "$install_disk" name 4 POPOS >/dev/null 2>&1

# create encrypted partition
echo -n "$password" | cryptsetup luksFormat /dev/disk/by-partlabel/POPOS -

# open encrypted partition
echo -n "$password" | cryptsetup luksOpen /dev/disk/by-partlabel/POPOS cryptdata -

# create physical volume
pvcreate /dev/mapper/cryptdata
# create volume group
vgcreate data /dev/mapper/cryptdata
# create logical volume
lvcreate -n root -l 100%FREE data

# close volumes
cryptsetup luksClose /dev/mapper/data-root
cryptsetup luksClose /dev/mapper/cryptdata
