#!/usr/bin/env bash

check_exist() {
  while ! [ -e "$1" ]; do
    sleep 0.5
  done
}

get_passwd() {
  password="1"
  check="2"

  while [ $password != $check ]; do
    read -sr -p "Enter passphrase for disk encryption: " password
    read -sr -p "Repeat passphrase: " check
  done

  printf "%s" "$password"
}
