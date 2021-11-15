#!/usr/bin/env bash

install_disk=$1
main_partition=""
efi_partition=""

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [[ $install_disk == *"nvme"* ]]; then
  main_partition=$install_disk"p3"
  efi_partition=$install_disk"p3"
else
  main_partition=$install_disk"3"
  efi_partition=$install_disk"3"
fi

cryptsetup luksOpen "$main_partition" cryptdata

mount -o subvolid=5,ssd,noatime,space_cache,commit=120,compress=zstd,discard=async /dev/mapper/data-root /mnt

# create root subvolume and move files
btrfs subvolume create /mnt/@
ls | grep -v /mnt/@ | xargs mv -t /mnt/@

# create home subvolume and move files
btrfs subvolume create /mnt/@home
mv /mnt/@/home/* /mnt/@home/

# adjust fstab
sed -i 's/btrfs  defaults/btrfs  defaults,subvol=@,ssd,noatime,space_cache,commit=120,compress=zstd,discard=async/' /mnt/@/etc/fstab
echo "UUID=$(blkid -s UUID -o value /dev/mapper/data-root)  /home  btrfs  defaults,subvol=@home,ssd,noatime,space_cache,commit=120,compress=zstd,discard=async   0 0" >> /mnt/@/etc/fstab

# adjust crypttab
sed -i 's/luks/luks,discard/' /mnt/@/etc/crypttab

mount "$efi_partition" /mnt/@/boot/efi

echo "timeout 3" >> /mnt/@/boot/efi/loader/loader.conf
echo "console max" >> /mnt/@/boot/efi/loader/loader.conf

sed -i 's/splash/splash rootflags=subvol=@/' /mnt/@/boot/efi/loader/entries/Pop_OS-current.conf