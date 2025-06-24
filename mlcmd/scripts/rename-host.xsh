#!/bin/sh mlcmd
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# Initialize a node on startup
. init


[ $# -ne 3 ] && usage "$0: server hostid newname"


HOSTS_URI=/manage/v2/hosts
SERVER="$1"
HOSTID="$2"
HOST="$3"

message "Renaming host to $HOST on $SERVER"
xquote -n <[
  <host-properties xmlns="http://marklogic.com/manage">
     <host-name>{$HOST}</host-name>
  </host-properties>
]> >{cfg}



#message "Sending rename request to $SERVER"
rest-request $SERVER "$HOSTS_URI/$HOSTID/properties" 8002 -X PUT -H "Content-type:application/xml" $CURL_AUTH -d $cfg >{r}
RET=$?
message "Rename request returns $RET" {$r}
if  [ $RET = 200 ] ; then
  message "Host rename succeeded: $RET - no restart needed"
  exit 0
elif  [ $RET = 204 ] ; then
  message "Host rename succeeded: $RET  - no restart needed"
  # message "SERIOUS HACK: do a service restart in 30 seconds"
  message "Perform a service restart in 30 seconds"
  
  sh -c "sleep 30;service MarkLogic restart;" &
  exit 0
elif  [ $RET = 503 ] ; then
  message "Failed to rename host: $RET - retry needed" {$r}
  exit 1
elif  [ $RET != 202 ] ; then
   message "Error $RET renaming host " {$r}
   error "Failed to update hostname on server $SERVER"
fi
echo $r | xread result
last=<[ $result//m:last-startup/string() ]>
if [ -z "$last" ] ; then 
        message "Unexpected blank timestamp from rename request - retrying" {$r}
        sleep 10
        exit 1
else
        message  "Waiting for server restart - $last" {$r}
	wait-for-startup -secure -host $MARKLOGIC_HOSTNAME  -ts "$last" -retries 2
fi

exit 0
