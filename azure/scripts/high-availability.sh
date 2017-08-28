#!/bin/bash
######################################################################################################
# File         : high-availability.sh
# Description  : Use this script to configure high availability on MarkLogic Server
# Usage        : sh high-availability.sh user password auth_mode hostname
######################################################################################################

USER=$1
PASS=$2
AUTH_MODE=$3
HOST=$4

# log file to record all the activities
LOG="/tmp/high-availability-$(date +"%Y%m%d%h%m%s").log"
# Suppress progress meter, but still show errors
CURL="curl -s -S"
# add authentication related options
AUTH_CURL="${CURL} --${AUTH_MODE} --user ${USER}:${PASS}"

echo "Sending configuration query to server..." >> $LOG
$AUTH_CURL -X POST -d @./configure-ha.xqy "http://${HOST}:8000/v1/eval" |& tee -a $LOG