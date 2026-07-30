#!/system/bin/sh

## FKM Method B 1:1 — extracted from q5/b.java (switchroot chroot script)

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

# Mount tmpfs for update-binary workspace (replaces switchroot chroot)
TMP=$F/tmp
$F/busybox umount $TMP 2>/dev/null
$F/busybox rm -rf $TMP 2>/dev/null
$F/busybox mkdir -p $TMP
$F/busybox mount -t tmpfs -o noatime tmpfs $TMP

# Inject busybox into update-binary's AKHOME/tools (same as flash_ak3.sh)
PATTERN='\$[Bb][Bb] chmod -R 755 tools bin;'
sed -i "/$PATTERN/i cp -f \"\$F/busybox\" \$AKHOME/tools;" "$F/update-binary"

# === FKM slot detection (exact copy from q5/b.java) ===
echo "Detecting active slot ..."
SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null)
test "$SLOT" || SLOT=$(grep -o 'androidboot.slot_suffix=[^ $]*' /proc/cmdline | cut -d\  -f1 | cut -d= -f2)
if [ ! "$SLOT" ]; then
  SLOT=$(getprop ro.boot.slot 2>/dev/null)
  test "$SLOT" || SLOT=$(grep -o 'androidboot.slot=[^ $]*' /proc/cmdline | cut -d\  -f1 | cut -d= -f2)
  test "$SLOT" && SLOT=_$SLOT
fi
echo "Slot: $SLOT"

# FKM: create non-suffixed by-name symlinks (exact copy)
echo "Creating by-name symlinks ..."
if [ "$SLOT" ]; then
  for i in /dev/block/bootdevice/by-name/*$SLOT; do
    j=$(echo $i | rev | cut -c3- | rev)
    if [ ! -e "$j" ]; then
      ln -sf $i $j
      LINKS="$LINKS$j "
    fi
  done
fi

# FKM: generate /etc/fstab from /proc/mounts
mkdir /etc 2>/dev/null
grep -E ' /system | /vendor | /product | /data | /cache | /persist ' /proc/mounts | sed 's;/dev/root;/dev/block/bootdevice/by-name/system;' | awk '{ print $1, $2, $3, $4 }' > /etc/fstab 2>/dev/null

# FKM: make /system busy to avoid unmount
echo "Keeping /system busy ..."
/system/bin/sleep 20 &

# Run update-binary — same as FKM: ash /tmp/update-binary 3 1 "$Z"
echo "Running update-binary ..."
AKHOME=$TMP/anykernel $F/busybox ash $F/update-binary 3 1 "$Z"
RC=$?
echo "update-binary exit code: $RC"

# FKM: clean up tracked symlinks
test "$LINKS" && rm -f $LINKS

# Cleanup tmpfs workspace (same as flash_ak3.sh)
$F/busybox umount $TMP
$F/busybox rm -rf $TMP
$F/busybox mount -o ro,remount -t auto /
$F/busybox rm -f $F/update-binary $F/busybox
mv $F/busybox_orig $F/busybox

safereturn() { return $RC; }
safereturn
