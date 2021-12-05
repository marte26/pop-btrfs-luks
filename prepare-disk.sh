#!/usr/bin/env bash

source ./utilities.sh

FS="/cdrom/casper/filesystem.squashfs"
REMOVE="/cdrom/casper/filesystem.manifest-remove"

disk=$1
#ram=$(($(free -m | awk '/Mem:/ {print $2}') + 4598))

hostname="pop-os"
username="pop-user"
keyboard="us"
language="en_US.UTF-8"

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

if ! [ -e "$disk" ]; then
  echo "Selected disk not valid"
  exit
fi

password=$(get_passwd)

# start the automated pop os installer
distinst -s "$FS" \
  -r "$REMOVE" \
  -h "$hostname" \
  -k "$keyboard" \
  -l "$language" \
  -b "$disk" \
  -t "$disk:gpt" \
  -n "$disk:primary:start:526M:fat32:mount=/boot/efi:flags=esp" \
  -n "$disk:primary:526M:4825M:fat32:mount=/recovery" \
  -n "$disk:primary:4825M:end:enc=cryptdata,data,pass=$password" \
  --logical "data:root:-4299M:btrfs:mount=/" \
  --logical "data:swap:4299M:swap"
