# Copyright 2002-2018 MarkLogic Corporation.  All Rights Reserved.
#
#!/bin/bash
######################################################################################################
#	File         : init-additional-node.sh
#	Description  : Use this script to initialize and add one or more hosts to a
# 				       MarkLogic Server cluster. The first (bootstrap) host for the cluster should already
#                be fully initialized.
# Usage        : sh init-additional-node.sh user password auth-mode n-retry retry-interval \
#                enable-high-availability license-key licensee bootstrap-node joining-host
######################################################################################################

source ./init.sh $1 "$2" $3 $4 $5

# variables
ENABLE_HA=$6
LICENSE_KEY=$7
LICENSEE=$8
BOOTSTRAP_HOST=$9
JOINING_HOST=${10}

#####################################################################################################
#
# Add the joining host to a cluster.
#
#####################################################################################################

write_conf $JOINING_HOST $LICENSE_KEY $LICENSEE

INFO "Adding host $JOINING_HOST to the cluster $BOOTSTRAP_HOST"
# initialize MarkLogic Server on the joining host
TIMESTAMP=`$CURL -X POST -d "" \
   http://${JOINING_HOST}:8001/admin/v1/init \
   |& tee -a $LOG \
   | grep "last-startup" \
   | sed 's%^.*<last-startup.*>\(.*\)</last-startup>.*$%\1%'`
if [ "$TIMESTAMP" == "" ]; then
  ERROR "Failed to initialize $JOINING_HOST"
  exit 1
fi

INFO "Checking server restart"
restart_check $JOINING_HOST $TIMESTAMP $LINENO

# retrieve the joining host's configuration
INFO "Retrieving the joining host's configuration"
JOINER_CONFIG=`$CURL -X GET -H "Accept: application/xml" \
    http://${JOINING_HOST}:8001/admin/v1/server-config |& tee -a $LOG`
echo $JOINER_CONFIG | grep -q "^<host"
if [ "$?" -ne 0 ]; then
  ERROR "Failed to fetch server config for $JOINING_HOST"
  exit 1
fi

#####################################################################################################
#
# Send the joining host's config to the bootstrap host, receive
# the cluster config data needed to complete the join. Save the
# response data to cluster-config.zip.
#
#####################################################################################################

$AUTH_CURL --user $USER:"$PASS" -X POST -o cluster-config.zip -d "group=Default" \
      --data-urlencode "server-config=${JOINER_CONFIG}" \
      -H "Content-type: application/x-www-form-urlencoded" \
      http://${BOOTSTRAP_HOST}:8001/admin/v1/cluster-config |& tee -a $LOG
if [ "$?" -ne 0 ]; then
  ERROR "Failed to fetch cluster config from $BOOTSTRAP_HOST"
  exit 1
fi
if [ `file cluster-config.zip | grep -cvi "zip archive data"` -eq 1 ]; then
  ERROR "Failed to fetch cluster config from $BOOTSTRAP_HOST"
  exit 1
fi

#####################################################################################################
#
# Send the cluster config data to the joining host, completing
# the join sequence.
#
#####################################################################################################

INFO "Sending the cluster config data to the joining host"
TIMESTAMP=`$CURL -X POST -H "Content-type: application/zip" \
    --data-binary @./cluster-config.zip \
    http://${JOINING_HOST}:8001/admin/v1/cluster-config \
    |& tee -a $LOG \
    | grep "last-startup" \
    | sed 's%^.*<last-startup.*>\(.*\)</last-startup>.*$%\1%'`
INFO "Checking server restart"
restart_check $JOINING_HOST $TIMESTAMP $LINENO
rm ./cluster-config.zip
INFO "$JOINING_HOST successfully added to the cluster"

if [ "$ENABLE_HA" == "True" ]; then
  INFO "Configurating high availability on the cluster"
  . ./high-availability.sh $USER "$PASS" $AUTH_MODE $BOOTSTRAP_HOST
fi