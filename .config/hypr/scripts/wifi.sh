#!/usr/bin/env bash

if [ "$(nmcli radio wifi)" = "enabled" ]; then
  nmcli radio wifi off
  echo "Disabled Wifi"
else
  nmcli radio wifi on
  echo "Enbabled Wifi"
fi
