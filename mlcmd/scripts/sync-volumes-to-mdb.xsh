# sync-volumes-to-mdb
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
#
## See ec2-startup
## This function will overwrite any existing mdb volumes
##

. init
assert-managed

message "Syncing local system volumes to mdb"
#TODO: make a batch request 
  mdb-delete-attributes device
  _ebs=get-ebs-devices()
  for e in <[ $_ebs[@status = "attached"]  ]> ; do
    _ebs=<[ $e/@name/string() ]>
    _mount=get-os-mountpoint($_ebs)   # default mountpoint
    _dev=get-os-device-name($_ebs)    # actual device ID
    _volid=<[ $e/@volume-id/string() ]>


   [ -z "$_mount" ] && continue ; # skip any EBS devices outside the managed range

# Check if device might be mounted at non-default location   
   while read dev dir rest ;   do
      if [ x"$dev" = x"$_dev" ] ; then 
         _mount=$dir
         break;
      fi
   done < /proc/mounts 

    if [ -n "$_mount" ] ; then 
      message "Updating MDB device record for ebs: $_ebs device: $_dev volid: $_volid mount: $_mount"
      mdb-add-device-entry  "$_ebs" "$_dev" "$_volid" "$_mount"
    fi
  done
exit 0
