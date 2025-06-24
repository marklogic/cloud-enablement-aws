#
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
. init
assert-managed-or-autocreate

if ! is-authenticated ; then
  message "Cannot initialize security" xlocation()
  exit 1;
fi

message "Initializing security database with admin name and password" xlocation()

# Wait for server to be up
if ! wait-for-startup "$@" ; then
  error "Error waiting for server to startup" xlocation()
fi


# export vars to xquery
pass="$MARKLOGIC_ADMIN_PASSWORD"
user="$MARKLOGIC_ADMIN_USERNAME"

xquote -n <[
<instance-admin xmlns="http://marklogic.com/manage">
   <admin-password>{$pass}</admin-password>
   <admin-username>{$user}</admin-username>
   <realm>public</realm>
</instance-admin>
]> >{sec}


# Wait an extra long time for this and dont retry, its not idempotent
rest-request localhost /admin/v1/instance-admin 8001 -X POST  -H "Content-type:application/xml" -d $sec >{r}
RET=$?
if  [ $RET != 202 ] ; then
   error "Failed to initialize admin username - HTTP return $RET" {$r}
fi
echo $r | xread result
last=<[ $result//m:last-startup/string() ]>
message  "Waiting for server restart - $last"
wait-for-startup -secure -ts $last -retries 10

