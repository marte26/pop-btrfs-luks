#!/usr/bin/env bash

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
    [ "$password" != "$check" ] || break
  done

  printf "%s" "$password"
}
