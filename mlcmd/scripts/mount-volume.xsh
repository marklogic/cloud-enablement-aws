# 
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# mount-volume device volume
#
. init
[ $# -ne 2 ] && usage "$0: ebs-device volume"

_ebs=$1
_mount=$2
_uuid=$(blkid -s UUID -o value $_ebs)
_dev=$(blkid -U ${_uuid} -o full)
message "UUID dev mapping: $_dev"
[ -z "$_dev" ] && _dev=get-os-device-name($_ebs)
message "Final dev mapping: $_dev"
[ -z "$_dev" ] && error "There is no associated OS device for EBS device $_ebs"

message "Attempting to mount EBS device $_ebs OS device $_dev on mountpoint $_mount"

if mountpoint -q $_mount; then
  if [ "$MARKLOGIC_FSTYPE" = "xfs" ] ; then
    xfs_growfs -d $_mount || error "Failed to xfs_growfs $_mount"
    logger -t MarkLogic "Successfully xfs_growfs $_mount."
  fi
  error "Mountpoint: $_mount is already mounted  - skipping"
fi

[ -f $_mount ] && error "Mountpoint $_mount is a normal file"
if [ -d $_mount ] ; then 
   _files=$(ls $_mount | wc -l)
   [ "$_files" -ne 0 ] && error "Directory $_mount has contents - skipping "
fi


[ -d $_mount ] || mkdir -p $_mount
chmod a-w $_mount

_BLK=$(blkid -p $_dev -o udev | grep ID_FS_USAGE )

message "Checking for filesystem on $_dev"  "$_BLK"

_USAGE=$( eval "$_BLK" ; echo $ID_FS_USAGE )
if [ "$_USAGE" = "filesystem" ] ; then
  message "Device $_dev has a filesystem - preserving"
else
  message "Creating a new filesystem $MARKLOGIC_FSTYPE on $_dev - old usage $_USAGE" $(blkid -p $_dev -o udev)
  if [ "$MARKLOGIC_FSTYPE" = "xfs" ] ; then
    mkfs -t $MARKLOGIC_FSTYPE -f $_dev >{r} 2>&1 || error "Failed to make a filesystem on $_dev" {$r}
  else
    mkfs -t $MARKLOGIC_FSTYPE -m 0 -F $_dev >{r} 2>&1 || error "Failed to make a filesystem on $_dev" {$r}
  fi
fi

message "Mounting filesystem from $_dev on $_mount"
mount -o noatime,nodev $_dev $_mount || error "Failed to mount device $_dev at mountpoint $_mount"
chown ${MARKLOGIC_USER}: $_mount || message "Failed to set owner $MARKLOGIC_USER to $_mount"
chmod u+rw $_mount || message "Failed to set read-write permissions on $_mount"


# Only update mdb on managed nodes
! is-managed && exit 0 
_volid=get-ebs-volume-id( $_ebs ) 
while [ -z "$_volid" ]  ; do
  message "Cannot find volumeid for $_ebs - waiting"  
  sleep 10 
  _volid=get-ebs-volume-id( $_ebs ) 
done

message "Updating MDB device record for ebs: $_ebs device: $_dev volid: $_volid mount: $_mount"
mdb-add-device-entry "$_ebs" "$_dev" "$_volid" "$_mount"
tag-ebs-volume $_volid $_ebs
exit 0
