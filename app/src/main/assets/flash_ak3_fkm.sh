#!/system/bin/sh

## FKM Method B 1:1 — AK3 zip via switchroot-style chroot
## Symlinks → /system busy → extract update-binary → ash

# Extract update-binary from zip
unzip -p "$Z" META-INF/com/google/android/update-binary > $F/update-binary
chmod 755 $F/update-binary

# FKM A/B slot detection
SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null)
test "$SLOT" || SLOT=$(grep -o 'androidboot.slot_suffix=[^ $]*' /proc/cmdline | cut -d= -f2)
test "$SLOT" || SLOT="_a"

# FKM: create non-suffixed by-name symlinks
for i in /dev/block/bootdevice/by-name/*$SLOT; do
  j=$(echo "$i" | rev | cut -c3- | rev)
  [ -e "$j" ] || ln -sf "$i" "$j" 2>/dev/null
done

# FKM: keep /system busy to prevent unmount
/system/bin/sleep 20 &

# FKM: run update-binary via ash
ash $F/update-binary 3 1 "$Z"
RC=$?

rm -f $F/update-binary
return $RC
