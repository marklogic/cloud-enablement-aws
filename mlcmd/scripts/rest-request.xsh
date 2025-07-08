#!/bin/sh mlcmd
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# Make a REST request  - by trying HTTP first, then HTTPS
. init

[ $# -lt 3 ] && usage "$0: host path port xargs"


HOST=$1
REQ_PATH=$2
PORT=$3
shift 3

URL=$(rest-uri -host $HOST -port $PORT -path $REQ_PATH -scheme http)
curl $URL $CURL_OPT -w " STATUS CODE: %{http_code}" $@ >{curl_res}
RET=$?
STATUS=<[fn:tokenize(fn:substring-after($curl_res, " STATUS CODE: "), " ")[1]]>
BODY=<[fn:substring-before($curl_res, " STATUS CODE: ")]>

HTTPS=<[fn:contains($curl_res, "You have attempted to access an HTTPS server using HTTP")]>
if [ "$HTTPS" = "true" ] || [ "$RET" = "56" ] ; # bug:54045
then
    PEM="$MARKLOGIC_DATA_DIR/Temp/$PORT-ca.pem"
    URL=$(rest-uri -host $HOST -port $PORT -path $REQ_PATH -scheme https)
    if [ -f "$PEM" ] ;
    then
        curl $URL -w " STATUS CODE: %{http_code}" --cacert "$PEM" $CURL_OPT $@ >{curl_res}
    else # bug:54033
        curl $URL -w " STATUS CODE: %{http_code}" -k $CURL_OPT $@ >{curl_res}
fi
STATUS=<[fn:tokenize(fn:substring-after($curl_res, " STATUS CODE: "), " ")[1]]>
BODY=<[fn:substring-before($curl_res, " STATUS CODE: ")]>
fi

echo "$BODY"
exit "$STATUS"
