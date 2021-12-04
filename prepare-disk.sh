#!/usr/bin/env bash

install_disk=$1
ram=$(($(free -m | awk '/Mem:/ {print $2}') + 4598))

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# create gpt partition table
parted "$install_disk" mklabel gpt
# create boot partition
parted "$install_disk" mkpart primary fat32 2Mib 502Mib
# create pop os recovery partition
parted "$install_disk" mkpart primary fat32 502MiB 4598MiB
# create swap partition
parted "$install_disk" mkpart primary fat32 4598MiB $ram"MiB"
# create main partition
parted "$install_disk" mkpart primary $ram"MiB" 100%

# set flags and names
parted "$install_disk" name 1 EFI
parted "$install_disk" set 1 esp on
parted "$install_disk" name 2 recovery
parted "$install_disk" name 3 SWAP
parted "$install_disk" set 3 swap on
parted "$install_disk" name 4 POPOS

# create encrypted partition
cryptsetup luksFormat /dev/disk/by-partlabel/POPOS

# open encrypted partition
cryptsetup luksOpen /dev/disk/by-partlabel/POPOS cryptdata

# create physical volume
pvcreate /dev/mapper/cryptdata
# create volume group
vgcreate data /dev/mapper/cryptdata
# create logical volume
lvcreate -n root -l 100%FREE data

# close volumes
cryptsetup luksClose /dev/mapper/data-root
cryptsetup luksClose /dev/mapper/cryptdata
