#!/usr/bin/env bash

install_disk=""
main_partition=""

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [[ $install_disk == *"nvme"* ]]; then
  main_partition=$install_disk+"p3"
fi

# create gpt partition table
parted "$install_disk" mklabel gpt    \
  mkpart primary fat32 2Mib 502Mib    \ # create boot partition
  mkpart primary fat32 502MiB 4598MiB \ # create pop os recovery partition
  mkpart primary 4598MiB 100%           # create main partition

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