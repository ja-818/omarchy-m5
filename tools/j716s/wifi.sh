#!/bin/bash
# J716s Wi-Fi diagnosis: what security a network asks for, and what this Mac's Wi-Fi offers.
# Read-only, except that it installs the `iw` tool. Router MAC addresses are hidden.
# usage: wifi.sh [part of the network name]
name=${1:-}
mac='s/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/<mac>/g'
command -v iw >/dev/null || sudo pacman -S --needed --noconfirm iw >/dev/null
echo "== iwd $(iwctl --version 2>/dev/null) | kernel $(uname -r)"
echo "== this Mac's Wi-Fi: ciphers, offloads"
iw phy | sed -n '/Supported Ciphers/,/Available Antennas/p' | grep -E '\* ' | head -8
iw phy | grep -iE 'SAE|4WAY|4-way|PMKSA|BEACON_PROTECTION|EXT_KEY|CONTROL_PORT|OWE' | sed 's/^\s*//' | head -15
echo "== networks matching '${name}' (router's security)"
sudo iw dev wlan0 scan 2>&1 | awk -v n="$name" '
  /^BSS /{ if (blk ~ ("SSID: [^\n]*" n)) print blk; blk="" }
  { blk = blk "\n" $0 }
  END{ if (blk ~ ("SSID: [^\n]*" n)) print blk }' |
  grep -E '^BSS|SSID:|freq:|RSN:|WPA:|Version|Group cipher|Pairwise ciphers|Authentication suites|Capabilities: .*(MFP|PTKSA)|Group mgmt cipher' |
  sed -E "$mac" | head -60
echo "== iwd's view"
iwctl station wlan0 get-networks 2>/dev/null | sed -E 's/\x1b\[[0-9;]*m//g' | head -15
