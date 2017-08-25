#!/bin/bash
######################################################################################################
#	File         : init-additional-node.sh
#	Description  : Use this script to initialize and add one or more hosts to a
# 				       MarkLogic Server cluster. The first (bootstrap) host for the cluster should already 
#                be fully initialized.
# Usage        : sh init-additional-node.sh user password auth-mode n-retry retry-interval \
#                enable-high-availability bootstrap-node
######################################################################################################

USER=$1
PASS=$2
AUTH_MODE=$3
N_RETRY=$4
RETRY_INTERVAL=$5
ENABLE_HA=$6
BOOTSTRAP_HOST=$7
JOINING_HOST=$(curl ipinfo.io/ip)

# log file to record all the activities
LOG="/tmp/log-additional-node-$(date +"%Y%m%d%h%m%s").log"
# Suppress progress meter, but still show errors
CURL="curl -s -S"
# add authentication related options, required once security is initialized
AUTH_CURL="${CURL} --${AUTH_MODE} --user ${USER}:${PASS}"

#!!!!!!!!!!!for debugging purpose only, delete later!!!!!!!!!!!!
echo $@ >> $LOG

######################################################################################################
# restart_check(hostname, baseline_timestamp, caller_lineno)
#
# Use the timestamp service to detect a server restart, given a
# a baseline timestamp.
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

#####################################################################################################
#
# Add the joining host to a cluster.
# 
#####################################################################################################

echo "Writing data into /etc/marklogic.conf" >> $LOG
echo "export MARKLOGIC_HOSTNAME=$JOINING_HOST" >> /etc/marklogic.conf |& tee -a $LOG

echo "Restarting the server to pick up changes in /etc/marklogic.conf..." >> $LOG
/etc/init.d/MarkLogic restart |& tee -a $LOG
sleep 10

echo "Adding host to cluster: $JOINING_HOST..." >> $LOG
# initialize MarkLogic Server on the joining host
TIMESTAMP=`$CURL -X POST -d "" \
   http://${JOINING_HOST}:8001/admin/v1/init \
   |& tee -a $LOG \
   | grep "last-startup" \
   | sed 's%^.*<last-startup.*>\(.*\)</last-startup>.*$%\1%'`
if [ "$TIMESTAMP" == "" ]; then
  echo "ERROR: Failed to initialize $JOINING_HOST" >&2 >> $LOG
  exit 1
fi
echo "Checking server restart..." >> $LOG
restart_check $JOINING_HOST $TIMESTAMP $LINENO

# retrieve the joining host's configuration
echo "Retrieving the joining host's configuration..." >> $LOG
JOINER_CONFIG=`$CURL -X GET -H "Accept: application/xml" \
    http://${JOINING_HOST}:8001/admin/v1/server-config |& tee -a $LOG`
echo $JOINER_CONFIG | grep -q "^<host"
if [ "$?" -ne 0 ]; then
  echo "ERROR: Failed to fetch server config for $JOINING_HOST" >> $LOG
  exit 1
fi

#####################################################################################################
#
# Send the joining host's config to the bootstrap host, receive
# the cluster config data needed to complete the join. Save the
# response data to cluster-config.zip.
#
#####################################################################################################

$AUTH_CURL -X POST -o cluster-config.zip -d "group=Default" \
      --data-urlencode "server-config=${JOINER_CONFIG}" \
      -H "Content-type: application/x-www-form-urlencoded" \
      http://${BOOTSTRAP_HOST}:8001/admin/v1/cluster-config |& tee -a $LOG
if [ "$?" -ne 0 ]; then
  echo "ERROR: Failed to fetch cluster config from $BOOTSTRAP_HOST" >> $LOG
  exit 1
fi
if [ `file cluster-config.zip | grep -cvi "zip archive data"` -eq 1 ]; then
  echo "ERROR: Failed to fetch cluster config from $BOOTSTRAP_HOST" >> $LOG
  exit 1
fi

#####################################################################################################
#
#     Send the cluster config data to the joining host, completing 
#     the join sequence.
#
#####################################################################################################  

echo "Sending the cluster config data to the joining host..." >> $LOG
TIMESTAMP=`$CURL -X POST -H "Content-type: application/zip" \
    --data-binary @./cluster-config.zip \
    http://${JOINING_HOST}:8001/admin/v1/cluster-config \
    |& tee -a $LOG \
    | grep "last-startup" \
    | sed 's%^.*<last-startup.*>\(.*\)</last-startup>.*$%\1%'`
echo "Checking server restart..." >> $LOG
restart_check $JOINING_HOST $TIMESTAMP $LINENO
rm ./cluster-config.zip
echo "...$JOINING_HOST successfully added to the cluster." >> $LOG

if [ "$ENABLE_HA" == "True" ]; then
  echo "Configurating high availability on the cluster..." |& tee -a $LOG
  . ./high-availability.sh $USER $PASS $AUTH_MODE $BOOTSTRAP_HOST |& tee -a $LOG
fi