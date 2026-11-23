#!/bin/bash
# Keep the J716s boot file (Stage 2: Wi-Fi fix, display, GPU, camera, sound) through system updates.
# A package update can rebuild /boot/efi/m1n1/boot.bin and boot-ctxr.bin from stock parts
# (asahi-scripts' update-m1n1, the image's update-boot-ctxr), which would quietly undo those fixes.
# This saves the current, known-good file and adds a pacman hook that runs last in every
# transaction and puts it back if anything replaced it.
#
# usage: sudo bash j716s-keep-boot-file.sh install   save the current boot file (must be the expected build), add the hook
#        sudo bash j716s-keep-boot-file.sh adopt     after a deliberate new J716s boot file: make it the one kept
#        sudo bash j716s-keep-boot-file.sh remove    remove the hook and the saved copy
set -euo pipefail
EXPECTED=d811e55a374488fc3de42f6db458f663b8bb234f710143c35ca84d67896379b9   # j716s-audio-1
ESP=/boot/efi/m1n1
DIR=/usr/local/lib/j716s
GOOD=$DIR/boot-ctxr.bin
RESTORE=$DIR/keep-boot-file
HOOK=/etc/pacman.d/hooks/zz-j716s-keep-boot-file.hook

[[ $(id -u) == 0 ]] || { echo "run it with sudo" >&2; exit 1; }
sha() { sha256sum "$1" | cut -d' ' -f1; }

save() {
  local cur; cur=$(sha "$ESP/boot-ctxr.bin")
  [[ $(sha "$ESP/boot.bin") == "$cur" ]] || { echo "STOP: boot.bin and boot-ctxr.bin differ; nothing changed" >&2; exit 1; }
  if [[ $1 == check && $cur != "$EXPECTED" ]]; then
    echo "STOP: the boot file on the ESP is $cur, not the expected J716s build ($EXPECTED); nothing changed" >&2; exit 1
  fi
  install -Dm644 "$ESP/boot-ctxr.bin" "$GOOD"
  [[ $(sha "$GOOD") == "$cur" ]] || { echo "STOP: the saved copy does not verify" >&2; exit 1; }
  echo "saved the J716s boot file ($cur) as $GOOD"
}

case ${1:-} in
install)
  save check
  cat >"$RESTORE" <<'EOF'
#!/bin/sh
# Run by zz-j716s-keep-boot-file.hook after every pacman transaction (j716s-keep-boot-file.sh).
good=/usr/local/lib/j716s/boot-ctxr.bin
[ -f "$good" ] || exit 0
want=$(sha256sum "$good" | cut -d' ' -f1)
for f in /boot/efi/m1n1/boot-ctxr.bin /boot/efi/m1n1/boot.bin; do
  [ -f "$f" ] || continue
  [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$want" ] && continue
  cp "$good" "$f.j716s-tmp" && sync && mv "$f.j716s-tmp" "$f" && sync
  if [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$want" ]; then
    echo "J716s: an update replaced $f; the J716s boot file is back"
  else
    echo "J716s: could not put the J716s boot file back in $f: copy $good there by hand" >&2
  fi
done
EOF
  chmod 755 "$RESTORE"
  mkdir -p "$(dirname "$HOOK")"
  cat >"$HOOK" <<EOF
# J716s (j716s-keep-boot-file.sh): put the J716s boot file back if an update rebuilt it from stock parts.
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Operation = Remove
Target = *

[Action]
Description = Keeping the J716s boot file...
When = PostTransaction
Exec = $RESTORE
EOF
  echo "installed $HOOK: after every update, the J716s boot file is checked and put back if needed"
  ;;
adopt) save any ;;
remove) rm -f "$HOOK" "$RESTORE" "$GOOD"; echo "removed the hook and the saved boot file" ;;
*) sed -n '2,12p' "$0"; exit 1 ;;
esac
