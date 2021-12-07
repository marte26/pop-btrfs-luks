#!/usr/bin/env bash

get_sectors() {
  DISK_ID=$(printf "%s" "$DISK" | sed "s/\/dev\///")

  sect_size="$(cat /sys/block/"$DISK_ID"/queue/physical_block_size)"

  ((sectors = $1 * 1048576 / sect_size))

  printf "%s" "$sectors"
}

check_exist() {
  while ! [ -e "$1" ]; do
    sleep 0.5
  done
}

get_passwd() {
  prompt=$1
  confirm=$2

  while true; do
    read -sr -p "$prompt" password
    printf "\n"
    read -sr -p "$confirm" check
    printf "\n"
    if [[ "$password" != "$check" ]]; then
      printf "Passwords don't match\n"
    elif [[ -z "$password" ]]; then
      printf "Password cannot be empty\n"
    else
      break
    fi
  done

  printf "%s" "$password"
}

FS="/cdrom/casper/filesystem.squashfs"
REMOVE="/cdrom/casper/filesystem.manifest-remove"

DISK=$1

hostname="pop-os"
username="pop-user"
keyboard="us"
language="en_US.UTF-8"
tz="Etc/UTC"

if [ "$EUID" -ne 0 ]; then
  printf "Please run as root\n"
  exit 1
fi

if ! [ "${1}" ]; then
  printf "Must provide a block device as an argument\n"
  exit 1
fi

if ! [ -b "${1}" ]; then
  printf "Provided argument is not a block device\n"
  exit 1
fi

# If the disk path ends with a number, add a p.
if [ "${1: -1}" -eq "${1: -1}" ]; then
  DISK_PART="${1}p"
else
  DISK_PART="${1}"
fi

disk_password=$(get_passwd "Enter disk encryption password:" "Confirm disk password:")
user_password=$(get_passwd "Enter password for user $username:" "Confirm user password:")

# start the automated pop os installer
distinst -s "$FS" \
  -r "$REMOVE" \
  -h "$hostname" \
  -k "$keyboard" \
  -l "$language" \
  -b "$DISK" \
  -t "$DISK:gpt" \
  -n "$DISK:primary:start:$(get_sectors 500):fat32:mount=/boot/efi:flags=esp" \
  -n "$DISK:primary:$(get_sectors 500):$(get_sectors 4596):fat32:mount=/recovery" \
  -n "$DISK:primary:$(get_sectors 4596):end:enc=cryptdata,data,pass=$disk_password" \
  --logical "data:root:-$(get_sectors 4096):btrfs:mount=/" \
  --logical "data:swap:$(get_sectors 4096):swap" \
  --username "$username" \
  --password "$user_password" \
  --profile_icon "" \
  --tz "$tz"

cryptsetup luksOpen "/dev/${DISK_PART}3" cryptdata

check_exist /dev/mapper/data-root

mount -o subvolid=5,ssd,noatime,space_cache,commit=120,compress=zstd,discard=async /dev/mapper/data-root /mnt

# create root subvolume and move files
btrfs subvolume create /mnt/@
find /mnt -mindepth 1 -maxdepth 1 -not -path /mnt/@ -exec mv -t /mnt/@ {} \;

# create home subvolume and move files
btrfs subvolume create /mnt/@home
mv /mnt/@/home/* /mnt/@home/

# adjust fstab
sed -i 's/btrfs  defaults/btrfs  defaults,subvol=@,ssd,noatime,space_cache,commit=120,compress=zstd,discard=async/' /mnt/@/etc/fstab
printf "UUID=%s  /home  btrfs  defaults,subvol=@home,ssd,noatime,space_cache,commit=120,compress=zstd,discard=async   0 0\n" "$(blkid -s UUID -o value /dev/mapper/data-root)" >>/mnt/@/etc/fstab

# adjust crypttab
sed -i 's/luks/luks,discard/' /mnt/@/etc/crypttab

mount "/dev/${DISK_PART}1" /mnt/@/boot/efi

printf "console max\n" >>/mnt/@/boot/efi/loader/loader.conf

sed -i 's/splash/splash rootflags=subvol=@/' /mnt/@/boot/efi/loader/entries/Pop_OS-current.conf

umount -l /mnt

mount -o defaults,subvol=@,ssd,noatime,space_cache,commit=120,compress=zstd,discard=async /dev/mapper/data-root /mnt

cp ./chroot.sh /mnt/

for i in dev dev/pts proc sys run; do sudo mount -B /$i /mnt/$i; done

chroot /mnt /chroot.sh
