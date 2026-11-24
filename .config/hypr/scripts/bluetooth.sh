#!/bin/bash

if bluetoothctl show | grep -q "Powered: yes"; then
    bluetoothctl power off
    swayosd-client --custom-icon=bluetooth-disabled-symbolic --custom-message="Bluetooth Off"
else
    rfkill unblock bluetooth
    bluetoothctl power on
    swayosd-client --custom-icon=bluetooth-active-symbolic --custom-message="Bluetooth On"
fi
