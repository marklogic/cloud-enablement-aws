# ec2-attach-volume ebs-volume-id  ebs-device
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# passthrough to aws 
. init.xsh
aws:ec2-attach-volume "$@"
