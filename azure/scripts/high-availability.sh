# Copyright 2002-2018 MarkLogic Corporation.  All Rights Reserved.
#
#!/bin/bash
######################################################################################################
# File         : high-availability.sh
# Description  : Use this script to configure high availability on MarkLogic Server
# Usage        : sh high-availability.sh user password auth_mode hostname
######################################################################################################

source ./init.sh $1 "$2" $3

HOST=$4

INFO "Sending forest configuration query to server"
$AUTH_CURL --user $USER:"$PASS" -X POST -d @./configure-ha.txt "http://${HOST}:8000/v1/eval" |& tee -a $LOG
INFO "Forest local failover successfully configured"