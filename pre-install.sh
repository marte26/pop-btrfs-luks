#!/usr/bin/env bash

install_disk=$1
main_partition=""

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [[ $install_disk == *"nvme"* ]]; then
  main_partition=$install_disk"p3"
else
  main_partition=$install_disk"3"
fi

# create gpt partition table
parted "$install_disk" mklabel gpt
# create boot partition
parted "$install_disk" mkpart primary fat32 2Mib 502Mib
# create pop os recovery partition
parted "$install_disk" mkpart primary fat32 502MiB 4598MiB
# create main partition
parted "$install_disk" mkpart primary 4598MiB 100%

# create encrypted partition
cryptsetup luksFormat "$main_partition"

# open encrypted partition
cryptsetup luksOpen "$main_partition" cryptdata

# create physical volume
pvcreate /dev/mapper/cryptdata
# create volume group
vgcreate data /dev/mapper/cryptdata
# create logical volume
lvcreate -n root -l 100%FREE data

# close volumes
cryptsetup luksClose /dev/mapper/data-root
cryptsetup luksClose /dev/mapper/cryptdata