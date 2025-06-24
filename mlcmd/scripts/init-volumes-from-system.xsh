#
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# init-volumes-from-system
##
## See ec2-startup
## This will completly wipe out all device entries in MDB and create them from scratch
## If a device was dynamically created it will be discarded and recreated !!!!
##
## 


. init

message "Initialize Volumes"
# If this is the first time ever for this node then create volumes as needed and update sdb
##
##  MARKLOGIC_EBS is the local device name for the default data volume e.g "/dev/sdf"
##  MARKLOGIC_EBS_VOLUME is the volume spec used to create this device 
##

# Constructing group name from node name. Example NodeA# -> GroupA
group=$(printf $MARKLOGIC_NODE_NAME | sed "s/Node/Group/" | head -c -1)

if [ ! -b $MARKLOGIC_EBS -a -n "$MARKLOGIC_EBS_VOLUME"   ] ; then
    vol=get-indexed-value( "$MARKLOGIC_EBS_VOLUME" "$MARKLOGIC_NODE_INDEX" )
    if ! init-volume $vol $MARKLOGIC_EBS "MarkLogic-$group-Host$MARKLOGIC_NODE_INDEX-Volume0" ; then
       error "Failed to create initial volume $vol on $MARKLOGIC_EBS - aborting startup" ;
    fi
fi

[ -n "$MARKLOGIC_EBS_VOLUME1" ] && init-volume get-indexed-value( "$MARKLOGIC_EBS_VOLUME1" "$MARKLOGIC_NODE_INDEX" )  /dev/sdg "MarkLogic-$group-Host$MARKLOGIC_NODE_INDEX-Volume1"
[ -n "$MARKLOGIC_EBS_VOLUME2" ] && init-volume get-indexed-value( "$MARKLOGIC_EBS_VOLUME2" "$MARKLOGIC_NODE_INDEX" )  /dev/sdh "MarkLogic-$group-Host$MARKLOGIC_NODE_INDEX-Volume2"
[ -n "$MARKLOGIC_EBS_VOLUME3" ] && init-volume get-indexed-value( "$MARKLOGIC_EBS_VOLUME3" "$MARKLOGIC_NODE_INDEX" )  /dev/sdi "MarkLogic-$group-Host$MARKLOGIC_NODE_INDEX-Volume3"
[ -n "$MARKLOGIC_EBS_VOLUME4" ] && init-volume get-indexed-value( "$MARKLOGIC_EBS_VOLUME4" "$MARKLOGIC_NODE_INDEX" )  /dev/sdj "MarkLogic-$group-Host$MARKLOGIC_NODE_INDEX-Volume4"
[ -n "$MARKLOGIC_EBS_VOLUME5" ] && init-volume get-indexed-value( "$MARKLOGIC_EBS_VOLUME5" "$MARKLOGIC_NODE_INDEX" )  /dev/sdk "MarkLogic-$group-Host$MARKLOGIC_NODE_INDEX-Volume5"
[ -n "$MARKLOGIC_EBS_VOLUME6" ] && init-volume get-indexed-value( "$MARKLOGIC_EBS_VOLUME6" "$MARKLOGIC_NODE_INDEX" )  /dev/sdl "MarkLogic-$group-Host$MARKLOGIC_NODE_INDEX-Volume6"
[ -n "$MARKLOGIC_EBS_VOLUME7" ] && init-volume get-indexed-value( "$MARKLOGIC_EBS_VOLUME7" "$MARKLOGIC_NODE_INDEX" )  /dev/sdm "MarkLogic-$group-Host$MARKLOGIC_NODE_INDEX-Volume7"
[ -n "$MARKLOGIC_EBS_VOLUME8" ] && init-volume get-indexed-value( "$MARKLOGIC_EBS_VOLUME8" "$MARKLOGIC_NODE_INDEX" )  /dev/sdn "MarkLogic-$group-Host$MARKLOGIC_NODE_INDEX-Volume8"
[ -n "$MARKLOGIC_EBS_VOLUME9" ] && init-volume get-indexed-value( "$MARKLOGIC_EBS_VOLUME9" "$MARKLOGIC_NODE_INDEX" )  /dev/sdo "MarkLogic-$group-Host$MARKLOGIC_NODE_INDEX-Volume9"

ec2-wait-for-ebs-attachments || error "Error waiting for EBS attachments to complete"

_ebs=get-ebs-devices()
message "Mounting all attached EBS devices" {$_ebs}
for e in <[ $_ebs[@status = "attached"]  ]> ; do
   ebs_dev=<[ $e/@name/string() ]>
   _mount=get-os-mountpoint($ebs_dev)
   message "Found EBS Device:$ebs_dev mount: $_mount"
   if [ -n "$_mount" ] ; then 
      mount-volume $ebs_dev $_mount 
   else 
     message "Ignoring unmanaged ebs device $ebs_dev"
   fi
done 

exit 0
