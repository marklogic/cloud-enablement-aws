#!/bin/sh mlcmd
# Copyright (c) 2020 MarkLogic Corporation 
# get-hostid contact-host hostname
. init
[ $# -ne 2 ] && usage "$0: contact-host host"
CONTACT_HOST=$1
HOST=$2
HOST_STATUS=/manage/v2/hosts
message "Getting hostid from $CONTACT_HOST for $HOST"
status=$<(rest-request $CONTACT_HOST $HOST_STATUS 8002 $CURL_AUTH)
[ $? = 200 ] || error "Error contacting host $CONTACT_HOST" {$status}

id=<[ $status//h:list-item[h:nameref = $HOST]/h:idref/string() ]>
[ -z "$id" ] && error "Cannot find hostid for $HOST"
message "Hostid for $HOST is $id"
echo -n $id
exit 0


