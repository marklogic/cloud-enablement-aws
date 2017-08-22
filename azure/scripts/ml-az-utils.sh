#!/bin/bash
######################################################################################################
# File         : ml-az-utils.sh
# Description  : this script contains utilities for other scripts.
# Usage : sh ml-az-utils.sh log_file
######################################################################################################

LOG=$1

###########################################################################
# restart_check(hostname, baseline_timestamp, caller_lineno)
#
# Use the timestamp service to detect a server restart, given a
# a baseline timestamp. 
# Returns 0 if restart is detected, exits with an error if not.
###########################################################################

function restart_check {
  LAST_START=`$AUTH_CURL "http://$1:8001/admin/v1/timestamp"`
  for i in `seq 1 ${N_RETRY}`; do
    if [ "$2" == "$LAST_START" ] || [ "$LAST_START" == "" ]; then
      sleep ${RETRY_INTERVAL}
	LAST_START=`$AUTH_CURL "http://$1:8001/admin/v1/timestamp"`
    else 
      return 0
    fi
  done
  echo "ERROR: Line $3: Failed to restart $1" >> $LOG
  exit 1
}
