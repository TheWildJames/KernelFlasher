#!/system/bin/sh

## FKM Method B 1:1 — AK3 zip via switchroot-style chroot

echo "Flash AK3 Zip (FKM)"
echo "F=$F Z=$Z"

# Extract busybox from zip (same as FKM does in chroot: unzip tools/busybox)
echo "Extracting busybox from zip ..."
unzip -p "$Z" tools*/busybox > $F/busybox_ak
chmod 755 $F/busybox_ak
echo "busybox extracted"

# FKM A/B slot detection
echo "Detecting active slot ..."
SLOT=$($F/busybox_ak getprop ro.boot.slot_suffix 2>/dev/null)
test "$SLOT" || SLOT=$($F/busybox_ak grep -o 'androidboot.slot_suffix=[^ $]*' /proc/cmdline | $F/busybox_ak cut -d= -f2)
test "$SLOT" || SLOT="_a"
echo "Slot: $SLOT"

# FKM: create non-suffixed by-name symlinks
echo "Creating by-name symlinks ..."
for i in /dev/block/bootdevice/by-name/*$SLOT; do
  j=$(echo "$i" | rev | cut -c3- | rev)
  [ -e "$j" ] || $F/busybox_ak ln -sf "$i" "$j" 2>/dev/null
done

# FKM: keep /system busy to prevent unmount
echo "Keeping /system busy ..."
/system/bin/sleep 20 &

# Extract update-binary from zip
echo "Extracting update-binary ..."
$F/busybox_ak unzip -p "$Z" META-INF/com/google/android/update-binary > $F/update-binary
$F/busybox_ak chmod 755 $F/update-binary
echo "Running update-binary ..."

# FKM: run update-binary via ash
$F/busybox_ak ash $F/update-binary 3 1 "$Z"
RC=$?
echo "update-binary exit code: $RC"

$F/busybox_ak rm -f $F/update-binary $F/busybox_ak
return $RC
