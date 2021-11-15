# pop-btrfs-luks
Script to install Pop!_OS with BTRFS and LUKS

This [guide](https://mutschler.eu/linux/install-guides/pop-os-btrfs-21-04/#overview) in script form

## Installation
* Boot the Pop!_OS Live ISO
* Open a root terminal and run `prepare-disk.sh <disk>` 
* Run the Pop!_OS installer and select custom partition layout and select the partitions
* Once the installer has finished run `post-installer.sh`