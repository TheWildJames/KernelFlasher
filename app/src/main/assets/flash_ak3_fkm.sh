#!/system/bin/sh

## FKM Method B 1:1 — AK3 zip via switchroot-style chroot
## Matches flash_ak3.sh setup + FKM A/B slot + /system busy

echo "Flash AK3 Zip (FKM)"
echo "F=$F Z=$Z"

# Extract busybox + update-binary from zip
echo "Extracting tools from zip ..."
unzip -p "$Z" tools*/busybox > $F/busybox_ak
unzip -p "$Z" META-INF/com/google/android/update-binary > $F/update-binary
chmod 755 $F/busybox_ak $F/update-binary

# Test zip's busybox — if it works, use it
$F/busybox_ak >/dev/null 2>&1
if [ $? -eq 0 ]; then
  mv $F/busybox $F/busybox_orig
  mv $F/busybox_ak $F/busybox
fi

# Mount tmpfs for update-binary workspace (needed for AKHOME)
TMP=$F/tmp
$F/busybox umount $TMP 2>/dev/null
$F/busybox rm -rf $TMP 2>/dev/null
$F/busybox mkdir -p $TMP
$F/busybox mount -t tmpfs -o noatime tmpfs $TMP

# FKM A/B slot detection
echo "Detecting active slot ..."
SLOT=$($F/busybox getprop ro.boot.slot_suffix 2>/dev/null)
test "$SLOT" || SLOT=$($F/busybox grep -o 'androidboot.slot_suffix=[^ $]*' /proc/cmdline | $F/busybox cut -d= -f2)
test "$SLOT" || SLOT="_a"
echo "Slot: $SLOT"

# FKM: create non-suffixed by-name symlinks
echo "Creating by-name symlinks ..."
for i in /dev/block/bootdevice/by-name/*$SLOT; do
  j=$(echo "$i" | rev | cut -c3- | rev)
  [ -e "$j" ] || $F/busybox ln -sf "$i" "$j" 2>/dev/null
done

# FKM: keep /system busy to prevent unmount
echo "Keeping /system busy ..."
/system/bin/sleep 20 &

# Inject busybox into update-binary's AKHOME/tools (same as flash_ak3.sh)
PATTERN='\$[Bb][Bb] chmod -R 755 tools bin;'
sed -i "/$PATTERN/i cp -f \"\$F/busybox\" \$AKHOME/tools;" "$F/update-binary"

# Run update-binary — same as flash_ak3.sh but with FKM slot setup
echo "Running update-binary ..."
AKHOME=$TMP/anykernel $F/busybox ash $F/update-binary 3 1 "$Z"
RC=$?
echo "update-binary exit code: $RC"

# Cleanup — same as flash_ak3.sh
$F/busybox umount $TMP
$F/busybox rm -rf $TMP
$F/busybox mount -o ro,remount -t auto /
$F/busybox rm -f $F/update-binary $F/busybox
mv $F/busybox_orig $F/busybox

safereturn() { return $RC; }
safereturn
