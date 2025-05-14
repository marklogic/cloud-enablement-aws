#!/bin/sh mlcmd
# Copyright (c) 2020 MarkLogic Corporation 
. init

CLUSTHOST=$1

CONFIG_PATH="/admin/v1/server-config"
JOIN_PATH="/admin/v1/cluster-config"
TS_PATH="/admin/v1/timestamp"

message "Getting server config from localhost"
JOINER_CFG=$(mktemp -s .xml)
rest-request localhost $CONFIG_PATH 8001 -o $JOINER_CFG
RET=$?
[ $RET -eq 200 ] || error "Failed contacting localhost at $CONFIG_PATH.  Ret: $RET"

message "Getting timestamp from $CLUSTHOST"
rest-request $CLUSTHOST $TS_PATH 8001 $CURL_AUTH >{TS}
RET=$?
[ $RET -eq 200 ] || error "Failed contacting $CLUSTHOST at $TS_PATH.  Ret: $RET" {$TS}


CFG=$(mktemp -s .zip)
message "Sending join request to $CLUSTHOST saving as $CFG"
rest-request $CLUSTHOST $JOIN_PATH 8001 -X POST -H "Content-type:application/x-www-form-urlencoded" --data-urlencode "server-config@$JOINER_CFG" -d "group=Default" -o $CFG $CURL_AUTH
RET=$?
if [ $RET -eq 200 ] ; then
   message "Got cluster config from $CLUSTERHOST RET: $RET - no restart needed"
elif [ $RET -eq 202 ]  ; then

   message "Got cluster config from $CLUSTERHOST RET: $RET - restart needed"
   wait-for-startup -secure -host localhost -ts $TS -retries 10 || error "Failed waiting for localhost to restart"
   message  "Localhost successfully restarted first portion of join complete."
else
     local _data=$(<$CFG)
     rm -f $CFG
     error "Failed getting config file from $CLUSTHOST at $JOIN_PATH attempting to join cluster. Ret: $RET" {$_data}
fi

wait-for-startup -secure -host localhost -ts $TS -retries 10 || error "Failed waiting for localhost to restart"
message  "Localhost successfully restarted first portion of join complete."

# Get timestamp before we do a join in case it restarts
message "Getting localhost current timestamp"
rest-request localhost $TS_PATH 8001  >{TS2}
RET=$?
[ $RET -eq 200 ] || error "Failed contacting localhost at $TS_PATH.  Ret: $RET" {$TS2}
message "Timestamp on localhost is $TS2" 


message  "Sending join completion to localhost"
rest-request localhost $JOIN_PATH 8001 -X POST -H "Content-type:application/zip" --data-binary "@$CFG" >{r}
RET=$?
message "Join cluster repsonse: $RET" {$r}
rm -f $CFG
if [ $RET -eq 200  ] ; then 
   message "Join cluster succeeded without restart needed " ;
elif [ $RET -eq 202 ]  ; then
   message "Join cluster succeeded - needing a restart " ;
    message  "Waiting for localhost to restart $TS2"
    wait-for-startup -secure -host $MARKLOGIC_HOSTNAME -ts $TS2 -retries 10 || error "Failed waiting for localhost to restart"
elif [ $RET -eq 503 ] ; then 
  message "Failed joining cluster: $RET - retry needed" {$r}
else
    error  "Error attpting to post join completion to localhost: Ret: $RET" {$r}
fi 

exit 0

