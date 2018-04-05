# Copyright 2002-2018 MarkLogic Corporation.  All Rights Reserved.
#
#!/bin/bash
######################################################################################################
# File         : init.sh
# Description  : This initialize script defines variables and functions shared among other scripts.
# Usage        : sh init.sh username password auth-mode n-retry retry-interval
######################################################################################################

USER=$1
PASS=$2
AUTH_MODE=$3
N_RETRY=$4
RETRY_INTERVAL=$5
# log file to record all the activities
LOG_PREFIX=`caller | awk '{print \$2}' | sed -e 's/\.sh//g' | sed -e 's/\.\///g'`
LOG="/tmp/$LOG_PREFIX-$(date +"%Y%m%d%h%m%s").txt"
# Suppress progress meter, but still show errors
CURL="curl -s -S"
# add authentication related options, required once security is initialized
AUTH_CURL="${CURL} --${AUTH_MODE}"

######################################################################################################
# Function     : restart_check
# Description  : Use the timestamp service to detect a server restart, given a baseline timestamp.
# 				 Returns 0 if restart is detected, exits with an error if not.
# Usage        : restart_check(hostname, baseline_timestamp, caller_lineno)
######################################################################################################

function restart_check {
  LAST_START=`$AUTH_CURL --user $USER:"$PASS" "http://$1:8001/admin/v1/timestamp" |& tee -a $LOG`
  for i in `seq 1 ${N_RETRY}`; do
    if [ "$2" == "$LAST_START" ] || [ "$LAST_START" == "" ]; then
      WARN "Server didn't restart. Retry in $RETRY_INTERVAL seconds"
      sleep ${RETRY_INTERVAL}
	  LAST_START=`$AUTH_CURL --user $USER:"$PASS" "http://$1:8001/admin/v1/timestamp" |& tee -a $LOG`
    else
      INFO "Server successfully restarted"
      return 0
    fi
  done
  ERROR "Line $3: Failed to restart $1"
  exit 1
}

######################################################################################################
# Function     : write_conf
# Description  : Write environment variables in /etc/marklogic.conf
#                and restart MarkLogic Server to pick up the environment variables change.
# Usage        : write_conf(hostname, license_key, licensee)
######################################################################################################

function write_conf {

  INFO "Writing data into /etc/marklogic.conf"
  echo "export MARKLOGIC_HOSTNAME=$1" >> /etc/marklogic.conf |& tee -a $LOG
  echo "export MARKLOGIC_LICENSE_KEY=$2" >> /etc/marklogic.conf |& tee -a $LOG
  echo "export MARKLOGIC_LICENSEE=$3" >> /etc/marklogic.conf |& tee -a $LOG

  INFO "Restarting the server to pick up changes in /etc/marklogic.conf"
  /etc/init.d/MarkLogic restart |& tee -a $LOG
  sleep 10
}

######################################################################################################
# Function     : INFO, WARN, ERROR
# Description  : Log out the message in log file and console
# Usage        : INFO("message"), WARN("message"), ERROR("message")
######################################################################################################

function INFO {
  LOG "INFO" $@
}

function WARN {
  LOG "WARN" $@
}

function ERROR {
  LOG "ERROR" $@
}

function LOG {
  level="$1"
  shift 1
  msg="$@"
  timestamp=`date +%Y-%m-%d:%H:%M:%S:%3N`
  echo "[$timestamp] [$level] $msg" |& tee -a $LOG
}