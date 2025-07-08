#
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# init-volumes
# initialize volumes from the MDB database
. init

_mdb=mdb-get-attributes()

ec2-wait-for-ebs-attachments || error "Error waiting for EBS attachments to complete"

_wait=$_false
# 
# May be no volumes to sync to 
for _d in mdb-get-devices( $_mdb ) ; do
   # Fatal error to fail to initialize volume
   init-volume <[ $_d/volume/string() ]> <[ $_d/ebs/string() ]> || error "Failed to initialize volume  - aborting"
   _wait=$_true
done

if [ $_wait ] ; then 
   ec2-wait-for-ebs-attachments || error "Error waiting for EBS attachments to complete"
fi

# Now apply attached devices 
_ebs=get-ebs-devices()
for e in <[ $_ebs[@status = "attached"]  ]> ; do
   ebs_dev=<[ $e/@name/string() ]>
   local _mount=mdb-get-device-mount( $_mdb $ebs_dev )
   [ -z "$_mount" ] && _mount=get-os-mountpoint($ebs_dev)
   if [ -n "$_mount" ] ; then 
      mount-volume $ebs_dev $_mount 
   else 
     message "Ignoring unmanaged ebs device $ebs_dev"
   fi
done 

exit 0
