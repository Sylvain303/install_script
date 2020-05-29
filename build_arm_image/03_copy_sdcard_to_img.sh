#!/bin/bash
#
# Create the image file from the sdcard
#
# Usage:
#  ./03_copy_sdcard_to_img.sh /dev/sdcard_device
#
# the resulting image will be stored in $OUTPUT_DIR
#
# Status: prototype
# Licence: GPLv3
# Author: sylvain303@github

OUTPUT_DIR=/media/sylvain/USBDISK/cleandrop

die() {
    1>&2 echo "$*"
    kill $$
}

# helper, test if a shell program exists in PATH
test_tool() {
    local cmd=$1
    if type $cmd > /dev/null
    then
        # OK
        return 0
    else
        die "tool missing: $cmd"
    fi
}

decho()
{
    >&2 echo "$*"
}

# helper, try to guess top device name
# /dev/sdp2 => /dev/sdp
# /dev/mmcblk0p1 => /dev/mmcblk0
# just some regexp, no smart thing
get_top_device() {
    local device="$1"
    local regexp1='^/dev/sd[a-z]'
    local regexp2='^/dev/mmcblk[0-9]'

    if [[ "$device" =~ $regexp1 ]]
    then
        decho sd
        device="${device/[0-9]/}"
    elif [[ "$device" =~ $regexp2 ]]
    then
        decho mmcblk
        device="${device/p[0-9]/}"
    else
      die "cannot match device: '$device' must be sdcard device name"
    fi

    echo "$device"
}

# helper, umount the sdcard partition if any
umount_sdcard_partition() {
    [[ -z "$SDCARD" ]] && { echo '$SDCARD is empty refusing to run'; return; }
    local p
    # search and replace all occurence of / by .
    local pattern=${SDCARD////.}
    pattern=${pattern/p[0-9]/}
    for p in $(df | awk "/^$pattern/ { print \$1 }")
    do
        sudo umount $p
    done
    echo "done device for sdcard=${pattern//.//}"
}

dd_from_sdcard() {
    [[ -z "$SDCARD" ]] && { echo '$SDCARD is empty refusing to run'; return; }
    [[ -z "$OUTPUT_IMG" ]] && { echo '$OUTPUT_IMG is empty refusing to run'; return; }
    local count
    if [[ ! -z "$1" ]]
    then
        count="count=$1"
    fi
    echo "starting dd if=$SDCARD  of=$OUTPUT_DIR/$OUTPUT_IMG"
    # ensure that sdcard partitions are unmounted with umount_sdcard_partition
    sudo dd bs=16M \
      status=progress \
      if=$SDCARD \
      of=$OUTPUT_DIR/$OUTPUT_IMG $count
}

test_all_tools() {
    for t in $*
    do
        test_tool $t
    done
}

# debug, not used
mount_sdcard_data_partition() {
    local part_data=2
    [[ ! -d $OUTPUT_DIR/sdcard ]] && mkdir $OUTPUT_DIR/sdcard
    sudo mount ${SDCARD}p2 $OUTPUT_DIR/sdcard
}

# prototype, not used. Wanna test if I can dd only used part of the partion, and fix it back on the PC
# not working yet, may be not achieved anyway…
get_used_partition_size() {
    local start_offset=$(sudo fdisk -l /dev/mmcblk0 | awk '/Linux/ { print $2 * 512 }')
    local used=$(df -B1 $OUTPUT_DIR/sdcard | awk '/dev.mmcblk0p2/ { print $3 }')

    echo "start_offset=$start_offset"
    echo "used        =$used"

    local count=$(($start_offset + $used))
    echo "count       =$count"
    local div=$(($count / (16 * 1048576) ))
    echo "16M         =$(($count /      (16 * 1048576) ))"
    echo "verif       =$(( ($div + 1) * (16 * 1048576) ))"
}

shrink_img() {
    echo "shrinking $OUTPUT_DIR/$OUTPUT_IMG"
    sudo ./autosizer.sh $OUTPUT_DIR/$OUTPUT_IMG
}

compress_image() {
  [[ -z "$OUTPUT_IMG" ]] && { echo '$OUTPUT_IMG is empty refusing to run'; return 1; }
  local img=$OUTPUT_DIR/$OUTPUT_IMG
  echo "compress_image: '$img'"
  time pigz -9 "$img"
  ls -lh "$img*"
}

# functions call in that order, edit remove a long running step if already done or if
# you want to skip it, step states are saved in folder $OUTPUT_DIR and skipped automatically.
STEPS="
umount_sdcard_partition
dd_from_sdcard
shrink_img
compress_image
"

# main wrapper, so the script can be sourced for debuging purpose or unittesting
main() {
    # positional argument must be script argument.
    # init
    if [[ -z "$1" ]]
    then
        echo "argument 1 error: expecting sdcard_device"
        exit 1
    fi

    test_all_tools dd sync sudo losetup
    if [[ ! -d $OUTPUT_DIR ]]
    then
        die "cannot find $OUTPUT_DIR/ folder are you following build step?"
    fi
    # reading script argument
    SDCARD=$(get_top_device "$1")
    DEST=cleandrop_RPI
    OUTPUT_IMG="$(date "+%Y-%m-%d")_${DEST}.img"

    # actions loop
    local s
    for s in $STEPS
    do
        echo -n "$s: "
        eval $s
    done
}

# sourcing code detection, if code is sourced for debug purpose, main is not executed.
[[ $0 != "$BASH_SOURCE" ]] && sourced=1 || sourced=0
if  [[ $sourced -eq 0 ]]
then
    # pass positional argument as is
    main "$@"
else
    # just print STEPS so I can copy/paste to call them interactivly
    echo "$STEPS"
fi
