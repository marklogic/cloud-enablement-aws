#!/bin/bash
######################################################################################################
# File         : init-bootstrap-node.sh
# Description  : This script will setup the first node in the cluster
# Usage        : sh init-bootstrap-node.sh username password auth-mode security-realm \
#                n-retry retry-interval hostname
######################################################################################################

# variables
USER=$1
PASS=$2
AUTH_MODE=$3
SEC_REALM=$4
N_RETRY=$5
RETRY_INTERVAL=$6
BOOTSTRAP_HOST=$7

# log file to record all the activities
LOG="/tmp/init-bootstrap-node-$(date +"%Y%m%d%h%m%s").log"
# Suppress progress meter, but still show errors
CURL="curl -s -S"
# add authentication related options, required once security is initialized
AUTH_CURL="${CURL} --${AUTH_MODE} --user ${USER}:${PASS}"

######################################################################################################
# restart_check(hostname, baseline_timestamp, caller_lineno)
#
# Use the timestamp service to detect a server restart, given a baseline timestamp. 
# Returns 0 if restart is detected, exits with an error if not.
######################################################################################################

function restart_check {
  LAST_START=`$AUTH_CURL "http://$1:8001/admin/v1/timestamp" |& tee -a $LOG`
  for i in `seq 1 ${N_RETRY}`; do
    if [ "$2" == "$LAST_START" ] || [ "$LAST_START" == "" ]; then
      echo "Server didn't restart. Retry in $RETRY_INTERVAL seconds..." >> $LOG
      sleep ${RETRY_INTERVAL}
	  LAST_START=`$AUTH_CURL "http://$1:8001/admin/v1/timestamp" |& tee -a $LOG`
    else
      echo "Server successfully restarted." >> $LOG
      return 0
    fi
  done
  echo "ERROR: Line $3: Failed to restart $1" >> $LOG
  exit 1
}

######################################################################################################
# Bring up the first host in the cluster. The following
# requests are sent to the target host:
#   (1) POST /admin/v1/init
#   (2) POST /admin/v1/instance-admin?admin-user=X&admin-password=Y&realm=Z
# GET /admin/v1/timestamp is used to confirm restarts.
######################################################################################################

echo "Writing data into /etc/marklogic.conf..." >> $LOG
echo "export MARKLOGIC_HOSTNAME=$BOOTSTRAP_HOST" >> /etc/marklogic.conf |& tee -a $LOG

echo "Restarting the server to pick up changes in /etc/marklogic.conf..." >> $LOG
/etc/init.d/MarkLogic restart |& tee -a $LOG
sleep 10

echo "Initializing $BOOTSTRAP_HOST..." >> $LOG
$CURL -X POST -d "" http://${BOOTSTRAP_HOST}:8001/admin/v1/init &>> $LOG
sleep 10

echo "Initializing database admin and security database..." >> $LOG
TIMESTAMP=`$CURL -X POST \
   -H "Content-type: application/x-www-form-urlencoded" \
   --data "admin-username=${USER}" --data "admin-password=${PASS}" \
   --data "realm=${SEC_REALM}" \
   http://${BOOTSTRAP_HOST}:8001/admin/v1/instance-admin \
   |& tee -a $LOG \
   | grep "last-startup" \
   | sed 's%^.*<last-startup.*>\(.*\)</last-startup>.*$%\1%'`
if [ "$TIMESTAMP" == "" ]; then
  echo "ERROR: Failed to get instance-admin timestamp." >&2 >> $LOG
  exit 1
fi

# Test for successful restart
echo "Checking server restart..." >> $LOG
restart_check $BOOTSTRAP_HOST $TIMESTAMP $LINENO

echo "Initialization complete for $BOOTSTRAP_HOST..." >> $LOG
exit 0