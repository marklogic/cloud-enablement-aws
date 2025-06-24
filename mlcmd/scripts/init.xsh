# initialize mlmd common
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# usage: . init
log "loading init.xsh"
if [ -z "$_MLCMD_INIT"  ]  ; then
   log "initializing mlcmd"
   [ -z "$MARKLOGIC_MLCMD_CONF" ] && MARKLOGIC_MLCMD_CONF=/var/local/mlcmd.conf
  if [ -f "$MARKLOGIC_MLCMD_CONF"  ] ;  then
      log "loading $MARKLOGIC_MLCMD_CONF"
       . $MARKLOGIC_MLCMD_CONF
  fi

  . functions
  _MLCMD_INIT=1
fi

# Reset varibles that may have changed since _MLCMD_INIT
CURL_OPT=(-s -S --retry 2)
CURL_AUTH=(--anyauth -u "$MARKLOGIC_ADMIN_USERNAME:$MARKLOGIC_ADMIN_PASSWORD")
INIT_STATUS_FILE=/var/local/mlcmd.init
[ -z "$MDB_NAME"  -a -n "$MARKLOGIC_CLUSTER_NAME" ]  && MDB_NAME="$MARKLOGIC_CLUSTER_NAME"
trace "complete init.xsh"