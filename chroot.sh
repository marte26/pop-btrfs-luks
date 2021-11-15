#!/usr/bin/env bash

mount -av

kernelstub --add-options "rootflags=subvol=@"

update-initramfs -c -k all