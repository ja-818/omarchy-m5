#!/bin/bash
# J716s quick report for the omarchy-m5 test template. Read-only.
# Prints one screen of facts; the full details go to ~/j716s-report.txt.
# No serial numbers, MAC addresses or user data.
mac='s/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/<mac>/g'
out=~/j716s-report.txt
{
  echo "== board";   tr -d '\0' </proc/device-tree/model; echo; tr '\0' ' ' </proc/device-tree/compatible; echo
  echo "== kernel";  uname -r
  sed -E 's/(root|cryptdevice|rd\.luks\.uuid)=[^ ]*/\1=<redacted>/g' /proc/cmdline
  echo "== cpus";    nproc; lscpu 2>/dev/null | grep -E 'Model name|CPU\(s\)|max MHz'
  echo "== drm";     for c in /sys/class/drm/card*; do echo "$(basename "$c") $(cat "$c/status" 2>/dev/null) $(head -1 "$c/modes" 2>/dev/null)"; done
  echo "== dri";     ls -l /dev/dri
  echo "== net";     ip -br addr | sed -E "$mac"
  echo "== bt";      bluetoothctl show 2>/dev/null | grep -vE 'Address|Name|Alias' | sed -E "$mac"
  echo "== usb";     lsusb 2>/dev/null; lsusb -t 2>/dev/null
  echo "== input";   grep -E '^N: Name=' /proc/bus/input/devices
  echo "== sound";   cat /proc/asound/cards 2>/dev/null
  echo "== video";   ls /dev/video* 2>/dev/null
  echo "== power";   for p in /sys/class/power_supply/*; do echo "$p: $(cat "$p/status" 2>/dev/null) $(cat "$p/capacity" 2>/dev/null)"; done
  echo "== backlight"; for b in /sys/class/backlight/*; do echo "$b: $(cat "$b/brightness")/$(cat "$b/max_brightness")"; done
  echo "== sleep";   cat /sys/power/mem_sleep 2>/dev/null
  echo "== failed";  systemctl --failed --plain --no-legend --no-pager
  echo "== kernel errors"; journalctl -b -k -p err -o cat --no-pager | sed -E "$mac" | tail -80
} >"$out" 2>&1

conn() { for c in /sys/class/drm/card*-*; do [ "$(cat "$c/status" 2>/dev/null)" = connected ] && printf '%s %s ' "${c##*/}" "$(head -1 "$c/modes")"; done; }
drv() { for c in /sys/class/drm/card? /sys/class/drm/renderD*; do [ -e "$c/device/driver" ] && printf '%s=%s ' "${c##*/}" "$(basename "$(readlink "$c/device/driver")")"; done; }

echo "Board:     $(tr -d '\0' </proc/device-tree/model)"
echo "Kernel:    $(uname -r)"
echo "CPUs:      $(nproc) online"
echo "Screen:    $(conn)"
echo "Graphics:  $(drv)"
echo "Wi-Fi:     $(ip -br addr show wlan0 2>/dev/null | awk '{print $2, $3}')"
echo "Bluetooth: $(bluetoothctl show 2>/dev/null | awk '/Powered/{print "powered " $2}')"
echo "USB:       $(lsusb 2>/dev/null | wc -l) devices"
echo "Sound:     $(grep -c '^ *[0-9]' /proc/asound/cards 2>/dev/null) cards"
echo "Camera:    $(ls /dev/video* 2>/dev/null | tr '\n' ' ')"
echo "Battery:   $(cat /sys/class/power_supply/*/capacity 2>/dev/null | head -1)% $(cat /sys/class/power_supply/*/status 2>/dev/null | head -1)"
echo "Backlight: $(ls /sys/class/backlight 2>/dev/null | tr '\n' ' ')"
echo "Sleep:     $(cat /sys/power/mem_sleep 2>/dev/null)"
echo "Failed:    $(systemctl --failed --plain --no-legend --no-pager | awk '{print $1}' | tr '\n' ' ')"
echo "Kernel errors this boot: $(journalctl -b -k -p err -o cat --no-pager | wc -l). Most common:"
journalctl -b -k -p err -o cat --no-pager | sed -E "$mac" | sort | uniq -c | sort -rn | head -8 | cut -c1-120
echo "Full details: $out"
