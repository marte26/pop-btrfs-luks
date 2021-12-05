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

# set name to easily identify luks partition
parted "$install_disk" name 4 POPOS >/dev/null 2>&1

cryptsetup luksOpen /dev/disk/by-partlabel/POPOS cryptdata

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
echo "UUID=$(blkid -s UUID -o value /dev/mapper/data-root)  /home  btrfs  defaults,subvol=@home,ssd,noatime,space_cache,commit=120,compress=zstd,discard=async   0 0" >>/mnt/@/etc/fstab

# adjust crypttab
sed -i 's/luks/luks,discard/' /mnt/@/etc/crypttab

mount /dev/sda1 /mnt/@/boot/efi

echo "timeout 3" >>/mnt/@/boot/efi/loader/loader.conf
echo "console max" >>/mnt/@/boot/efi/loader/loader.conf

sed -i 's/splash/splash rootflags=subvol=@/' /mnt/@/boot/efi/loader/entries/Pop_OS-current.conf

umount -l /mnt

mount -o defaults,subvol=@,ssd,noatime,space_cache,commit=120,compress=zstd,discard=async /dev/mapper/data-root /mnt

cp ./chroot.sh /mnt/

for i in dev dev/pts proc sys run; do sudo mount -B /$i /mnt/$i; done

chroot /mnt /chroot.sh
