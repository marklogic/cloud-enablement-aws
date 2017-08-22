#!/bin/bash
######################################################################################################
#	File         : init-additional-node.sh
#	Description  : Use this script to initialize and add one or more hosts to a
# 				       MarkLogic Server cluster. The first (bootstrap) host for the cluster should already 
#                be fully initialized.
# Usage        : sh filename.sh masternode user password auth-mode n-retry retry-interval joining-nodes
######################################################################################################

BOOTSTRAP_HOST=$1
USER=$2
PASS=$3
AUTH_MODE=$4
N_RETRY=$5
RETRY_INTERVAL=$6

# log file to record all the activities
LOG="/tmp/log-additional-node-$(date +"%Y%m%d%h%m%s").log"
# curl command
CURL="curl"
# add authentication related options, required once security is initialized
AUTH_CURL="${CURL} --${AUTH_MODE} --user ${USER}:${PASS}"

# for debugging purpose, delete later
echo $@ >> $LOG

######################################################################################################
# restart_check(hostname, baseline_timestamp, caller_lineno)
#
# Use the timestamp service to detect a server restart, given a
# a baseline timestamp.
# Returns 0 if restart is detected, exits with an error if not.
######################################################################################################

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

if [ $# -ge 7 ]; then
  BOOTSTRAP_HOST=$1
  shift 6
else
  echo "ERROR: At least two hostnames are required." >&2 >> $LOG
  exit 1
fi
ADDITIONAL_HOSTS=$@

#####################################################################################################
#
# Add one or more hosts to a cluster.
# 
#####################################################################################################

for JOINING_HOST in $ADDITIONAL_HOSTS; do
  echo "Adding host to cluster: $JOINING_HOST..." >> $LOG

  # initialize MarkLogic Server on the joining host
  TIMESTAMP=`$CURL -X POST -d "" \
     http://${JOINING_HOST}:8001/admin/v1/init \
     | grep "last-startup" \
     | sed 's%^.*<last-startup.*>\(.*\)</last-startup>.*$%\1%'`
  if [ "$TIMESTAMP" == "" ]; then
    echo "ERROR: Failed to initialize $JOINING_HOST" >&2 >> $LOG
    exit 1
  fi
  restart_check $JOINING_HOST $TIMESTAMP $LINENO
  
  # retrieve the joining host's configuration
    JOINER_CONFIG=`$CURL -X GET -H "Accept: application/xml" \
        http://${JOINING_HOST}:8001/admin/v1/server-config`
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
        http://${BOOTSTRAP_HOST}:8001/admin/v1/cluster-config
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
  
  TIMESTAMP=`$CURL -X POST -H "Content-type: application/zip" \
      --data-binary @./cluster-config.zip \
      http://${JOINING_HOST}:8001/admin/v1/cluster-config \
      | grep "last-startup" \
      | sed 's%^.*<last-startup.*>\(.*\)</last-startup>.*$%\1%'`
  restart_check $JOINING_HOST $TIMESTAMP $LINENO
  rm ./cluster-config.zip

  echo "...$JOINING_HOST successfully added to the cluster." >> $LOG
done