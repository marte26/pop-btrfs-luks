#!/usr/bin/env bash

function check_exist {
  while ! [ -e "$1" ]; do
    sleep 0.5
  done
}
