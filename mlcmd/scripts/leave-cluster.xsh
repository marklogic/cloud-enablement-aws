#
# Copyright (c) 2020 MarkLogic Corporation 
# leave-cluster  [-terminate]
#
. init
[ $# -eq 0 -o "x$1" = "x-terminate" ] || usage "$0 [-terminate]"
assert-authenticated

CONFIG_PATH=/admin/v1/host-config
message "Detaching host from cluster"
rest-request $MARKLOGIC_HOSTNAME $CONFIG_PATH 8001 -X DELETE $CURL_AUTH >{r}
RET=$?
message "Delete request returns $RET" {$r}
if  [ $RET = 200 ] ; then
  message "Host delete succeeded: $RET - no restart needed"
elif  [ $RET = 204 ] ; then
  error "Failed to delete host: $RET " {$r}
elif  [ $RET = 503 ] ; then
  error "Failed to delete host: $RET - retry needed" {$r}
elif  [ $RET != 202 ] ; then
  error "Error $RET  deleting host" {$r}
fi

echo $r | xread result
last=<[ $result//m:last-startup/string() ]>
if [ -z "$last" ] ; then
        message "Unexpected blank timestamp from delete request" {$r}
        exit 1
else
        message  "Waiting for server restart - $last" {$r}
        wait-for-startup -secure -host $MARKLOGIC_HOSTNAME  -ts "$last" -retries 2
fi

message "Removing host entry from MDB"
mdb-delete-item

if [ "x$1" = "x-terminate" ] ; then
   [ -z "$MARKLOGIC_INSTANCE" ] && error "Local instance unknown - configuration problem"
   message "Terminating instance $MARKLOGIC_INSTANCE"
   aws:as-terminate-instance -decrement $MARKLOGIC_INSTANCE ||
   error "Unable to terminate instance $MARKLOGIC_INSTANCE"
fi

exit 0
