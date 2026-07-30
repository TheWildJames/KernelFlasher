#!/system/bin/sh

## FKM-style AnyKernel3 zip flash via switchroot chroot approach
## Extracts update-binary, sets up A/B slot symlinks, runs via isolated ash

## setup:
unzip -p "$Z" tools*/busybox > $F/busybox_ak;
unzip -p "$Z" META-INF/com/google/android/update-binary > $F/update-binary;

chmod 755 $F/busybox_ak;
$F/busybox_ak >/dev/null 2>&1
if [ $? -eq 0 ]; then
  mv $F/busybox $F/busybox_orig
  mv $F/busybox_ak $F/busybox
fi
$F/busybox chmod 755 $F/update-binary;
$F/busybox chown root:root $F/busybox $F/update-binary;

## FKM-style A/B slot handling: create non-suffixed symlinks
SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null)
test "$SLOT" || SLOT=$(grep -o 'androidboot.slot_suffix=[^ $]*' /proc/cmdline | cut -d= -f2)
test "$SLOT" || SLOT="_a"

for i in /dev/block/bootdevice/by-name/*$SLOT; do
  j=$(echo "$i" | rev | cut -c3- | rev)
  if [ ! -e "$j" ]; then
    $F/busybox ln -sf "$i" "$j" 2>/dev/null
  fi
done

## FKM-style: mount tmpfs working dir
TMP=$F/tmp;
$F/busybox umount $TMP 2>/dev/null;
$F/busybox rm -rf $TMP 2>/dev/null;
$F/busybox mkdir -p $TMP;
$F/busybox mount -t tmpfs -o noatime tmpfs $TMP;

## FKM-style: inject busybox into AK3 tools
PATTERN='\$[Bb][Bb] chmod -R 755 tools bin;';
sed -i "/$PATTERN/i cp -f \"\$F/busybox\" \$AKHOME/tools;" "$F/update-binary";

## Run update-binary (FKM uses ash, same as KF but with chroot-style setup)
AKHOME=$TMP/anykernel $F/busybox ash $F/update-binary 3 1 "$Z";
RC=$?;

$F/busybox umount $TMP;
$F/busybox rm -rf $TMP;
$F/busybox mount -o ro,remount -t auto /;
$F/busybox rm -f $F/update-binary $F/busybox;
mv $F/busybox_orig $F/busybox

safereturn() { return $RC; }
safereturn;
