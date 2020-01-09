#!/bin/bash
#

usage()
{
    cat << EOT
Usage: ./push_sd_image.sh IMAGE_FILE

Will upload IMAGE_FILE to $REMOTE_DEST_SSH
EOT
}

set -euo pipefail

log()
{
    echo "$*"
    if [[ -n $LOGFILE ]] ; then
        d=$(date "+%Y-%m-%d_%H:%M:%S")
        sed -e "s/^/$d /g" <<< "$*" >> $LOGFILE
    fi
}

fetch_remote_list()
{
    log "============== fetching remote list on: $REMOTE_DEST_SSH"
    REMOTE_IMAGES_SD=$(ssh $REMOTE_DEST_SSH "ls -rt $DEST_DIR")
    log "received list:"
    log "$REMOTE_IMAGES_SD"
}


log_vars()
{
  local varname
  local v
  for varname in $*
  do
    eval "v=\$$varname"
    log "$varname: '$v'"
  done
}


############################### config ################################3

DEST_DIR=/home/deploy/sdcard
REMOTE_DEST_SSH=root@bob.cleandrop.fr
LOGFILE=./upload_sdcard.log

####################################### main

SCRIPT_DIR=$(dirname $(readlink -f $0))
cd $SCRIPT_DIR

if [[ $# -lt 1 ]] ; then
    usage
    exit 1
else
    if [[ $1 == '-h' || $1 == '--help' ]] ; then
      usage
      exit 0
    fi

    SD_IMAGE_NAME=$1
fi

if [[ -z $SD_IMAGE_NAME ]] ; then
  echo "error: var \$SD_IMAGE_NAME is empty"
  exit 1
fi

if [[ ! -e $SD_IMAGE_NAME ]] ; then
  echo "error: '$SD_IMAGE_NAME' file not found"
  exit 1
fi

echo "image sd found: '$SD_IMAGE_NAME'"
log_vars SD_IMAGE_NAME DEST_DIR REMOTE_DEST_SSH
DEST_IMAGE_NAME=$(basename $SD_IMAGE_NAME)

fetch_remote_list
for i in $REMOTE_IMAGES_SD
do
    if [[ "$DEST_IMAGE_NAME" == "$i" ]] ; then
        echo "already present: $i on $REMOTE_DEST_SSH"
        exit 1
    fi
done

log "uploading sdcard image: $DEST_IMAGE_NAME"

cmd="time scp $SD_IMAGE_NAME $REMOTE_DEST_SSH:$DEST_DIR/$DEST_IMAGE_NAME"
log "$cmd"
eval "$cmd"
log "scp ret code: $?"
