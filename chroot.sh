#!/usr/bin/env bash

mount -a

kernelstub --add-options "rootflags=subvol=@"

update-initramfs -c -k all
