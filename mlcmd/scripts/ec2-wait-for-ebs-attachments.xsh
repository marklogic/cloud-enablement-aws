# ec2-wait-for-ebs-attachments
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# Wait for all EBS devices in the process of attaching to be attached

. init
_ebs=get-ebs-devices()

message "Waiting for all pending EBS volumes to be attached" {$_ebs}
while [ <[ $_ebs/@status = "attaching" ]> ] ;  do
   message "Waiting for ebs devices to attach" <[ $_ebs[@status = "attaching"]/@name ]> 
   sleep 10 
   _ebs=get-ebs-devices()
done

message "Waiting for all OS block devices to be online" {$_ebs}
for e in <[ $_ebs[@status = "attached"]/@name/string()  ]> ; do
    dev=get-os-device-name($e)
    [ -b $dev ] && continue ;
    message "Waiting for block device $dev to come online" 
done

exit 0
