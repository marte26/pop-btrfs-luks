#!/usr/bin/env bash

get_sectors() {
  disk_part=$(echo -n "$disk" | sed "s/\/dev\///")

  sect_size="$(cat /sys/block/"$disk_part"/queue/physical_block_size)"

  ((sectors=$1*1048576/sect_size))

  echo -n "$sectors"
}

source ./utilities.sh

FS="/cdrom/casper/filesystem.squashfs"
REMOVE="/cdrom/casper/filesystem.manifest-remove"

disk=$1
#ram=$(($(free -m | awk '/Mem:/ {print $2}') + 4598))

hostname="pop-os"
username="pop-user"
keyboard="us"
language="en_US.UTF-8"
tz="Etc/UTC"

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
  -n "$disk:primary:start:$(get_sectors 500):fat32:mount=/boot/efi:flags=esp" \
  -n "$disk:primary:$(get_sectors 500):$(get_sectors 4596):fat32:mount=/recovery" \
  -n "$disk:primary:$(get_sectors 4596):end:enc=cryptdata,data,pass=$password" \
  --logical "data:root:-$(get_sectors 4096):btrfs:mount=/" \
  --logical "data:swap:$(get_sectors 4096):swap" \
  --username "$username" \
  --profile_icon "/usr/share/pixmaps/faces/penguin.png" \
  --tz "$tz"
