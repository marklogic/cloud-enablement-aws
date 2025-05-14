# ec2-attach-volume ebs-volume-id  ebs-device
# Copyright (c) 2020 MarkLogic Corporation 
# passthrough to aws 
. init.xsh
aws:ec2-attach-volume "$@"
