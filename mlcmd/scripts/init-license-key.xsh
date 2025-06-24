#
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# Initializes/Accepts the license agreement and any supplied license key
#
. init
message "Initializing server" xlocation()
# Wait for server to be up
if ! wait-for-startup "$@" ; then
  error "Error waiting for server to startup" xlocation()
fi

# export vars to xquery
fedramp="false"

# export vars to xquery
if [ ! -z "$MARKLOGIC_FEDRAMP"  ]; then
  fedramp="$MARKLOGIC_FEDRAMP"
fi

if [  $fedramp = "true"  ]; then
  message "Initializing FedRAMP environment" xlocation()
  if [ ! -z "$MARKLOGIC_P11_DRIVER_PATH"  ]; then
    p11-driver-path="$MARKLOGIC_P11_DRIVER_PATH"
    xquote -n <[
      <init xmlns="http://marklogic.com/manage">
        <fedramp>{$fedramp}</fedramp>
        <p11-driver-path>{$p11-driver-path}</p11-driver-path>
      </init>
    ]> >{init}
    rest-request localhost /admin/v1/init 8001 -X POST -H "Content-type:application/xml" -d $init >{r}
  fi
  if [ ! -z "$MARKLOGIC_KMS_HOST"  ]; then
    xquote -n <[
      <init xmlns="http://marklogic.com/manage">
        <fedramp>{$fedramp}</fedramp>
        <kms-host>{$MARKLOGIC_KMS_HOST}</kms-host>
        <kms-port>{$MARKLOGIC_KMS_PORT}</kms-port>
        <kms-data-key-id>{$MARKLOGIC_KMS_DATA_KEY}</kms-data-key-id>
        <kms-config-key-id>{$MARKLOGIC_KMS_CONFIG_KEY}</kms-config-key-id>
        <kms-logs-key-id>{$MARKLOGIC_KMS_LOGS_KEY}</kms-logs-key-id>
      </init>
    ]> >{init}
    rest-request localhost /admin/v1/init 8001 -X POST -H "Content-type:application/xml" -d $init >{r}
  fi
else
  xquote -n <[ <init xmlns="http://marklogic.com/manage"></init> ]> >{init}
  if [ ! -z "$MARKLOGIC_KMS_HOST"  ]; then
    xquote -n <[
      <init xmlns="http://marklogic.com/manage">
        <kms-host>{$MARKLOGIC_KMS_HOST}</kms-host>
        <kms-port>{$MARKLOGIC_KMS_PORT}</kms-port>
        <kms-data-key-id>{$MARKLOGIC_KMS_DATA_KEY}</kms-data-key-id>
        <kms-config-key-id>{$MARKLOGIC_KMS_CONFIG_KEY}</kms-config-key-id>
        <kms-logs-key-id>{$MARKLOGIC_KMS_LOGS_KEY}</kms-logs-key-id>
      </init>
    ]> >{init}
  fi
  rest-request localhost /admin/v1/init 8001 -X POST -H "Content-type:application/xml" -d $init >{r}
fi

RET=$?
if  [ $RET = 200 ] ; then
  message "License key was previously initialized - OK" xlocation()
  exit 0
elif  [ $RET = 204 ] ; then
  message "License Key was initialized - no restart needed" xlocation()
  exit 0
elif  [ $RET != 202 ] ; then
   message "Error returned from admin/v1/init: $RET " {$r}
   error "Failed to initialize server - HTTP return $RET" {$r}
fi
echo $r | xread result
last=<[ $result//m:last-startup/string() ]>
message  "Waiting for server restart - $last" xlocation()
wait-for-startup -host localhost -ts $last -retries 10
