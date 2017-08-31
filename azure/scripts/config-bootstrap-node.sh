#!/bin/bash
######################################################################################################
# File         : init-bootstrap-node.sh
# Description  : This script will setup the first node in the cluster
# Usage        : sh init-bootstrap-node.sh username password auth-mode security-realm \
#                n-retry retry-interval hostname
######################################################################################################

source ./init.sh $1 $2 $3

# variables
SEC_REALM=$4
N_RETRY=$5
RETRY_INTERVAL=$6
BOOTSTRAP_HOST=$7

######################################################################################################
# Bring up the first host in the cluster. The following
# requests are sent to the target host:
#   (1) POST /admin/v1/init
#   (2) POST /admin/v1/instance-admin?admin-user=X&admin-password=Y&realm=Z
# GET /admin/v1/timestamp is used to confirm restarts.
######################################################################################################

INFO "Writing data into /etc/marklogic.conf"
echo "export MARKLOGIC_HOSTNAME=$BOOTSTRAP_HOST" >> /etc/marklogic.conf |& tee -a $LOG

INFO "Restarting the server to pick up changes in /etc/marklogic.conf"
/etc/init.d/MarkLogic restart |& tee -a $LOG
sleep 10

INFO "Initializing $BOOTSTRAP_HOST"
$CURL -X POST -d "" http://${BOOTSTRAP_HOST}:8001/admin/v1/init &>> $LOG
sleep 10

INFO "Initializing database admin and security database"
TIMESTAMP=`$CURL -X POST \
   -H "Content-type: application/x-www-form-urlencoded" \
   --data "admin-username=${USER}" --data "admin-password=${PASS}" \
   --data "realm=${SEC_REALM}" \
   http://${BOOTSTRAP_HOST}:8001/admin/v1/instance-admin \
   |& tee -a $LOG \
   | grep "last-startup" \
   | sed 's%^.*<last-startup.*>\(.*\)</last-startup>.*$%\1%'`
if [ "$TIMESTAMP" == "" ]; then
  ERROR "Failed to get instance-admin timestamp"
  exit 1
fi

# Test for successful restart
INFO "Checking server restart"
restart_check $BOOTSTRAP_HOST $TIMESTAMP $LINENO

INFO "Initialization complete for $BOOTSTRAP_HOST"
exit 0