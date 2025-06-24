# 
# Copyright (c) 2013-2025 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# init-volume volume-spec  [volid]
. init
[ $# -lt 1 ] && usage "$0: volume-spec [volume-id]"

_SPEC=$1
_VOLID=$2
_VOLNAME=$3

case "$_VOLID" in 
  /dev/*) _DEV=$_VOLID ;;
  "")     _DEV=/dev/sdf ;;
  [1-9])  _DEV=get-ebs-device-name($_VOLID) ;;
  *) usage "$0: volume index must be blank or 1=9" ;;
esac

if [ -z "$_VOLNAME" ]; then
  _VOLNAME="MarkLogic-$MARKLOGIC_NODE_NAME$MARKLOGIC_NODE_INDEX-Volume"
fi



message "Attempting to initialize EBS volume $_SPEC at device $_DEV"

function attach-volume()
{
  local _id=$1
  local _dev=$2
  message "Attaching volume id $_id to attach EC2 device $_dev"
  aws:ec2-attach-volume -rate-retry 10 -i $MARKLOGIC_INSTANCE -d $_dev $_id  >{r} || error "Unable to attach volume $_id to device $_dev" {$r}
  tag-ebs-volume $_id $_dev
  message "Waiting for volume to be recognized on EBS"
  while true ; do
     sleep 30
     local _ebs=get-ebs-devices( $_dev )
     if [ <[ exists( $_ebs/@status ) and $_ebs/@status ne '' ]> ] ; then 
        break ;
    fi
    message "Waiting for $_dev to appear in EC2 instance attachments"
  done 
  
}

function wait-attach()
{
  local _id=$1
  local _dev=$2
  local _state=wait-for-volume-state($_id available)
  [ "$_state" = "available" ] || error "Volume did not successfully create"
  attach-volume $_id $_dev
}


# returns "" if not attached
# returns volumeid if attached
_ATTACHED=is-device-attached($_DEV)


# either vol-id or ec2 api spec
# [snapshot-id]:[volume-size]:[delete-on-termination]:[volume-type[:iops]]:[encrypted]


case $_SPEC in
# Attach a pre existing volume
vol-*) 
     if [ "$_ATTACHED" = "$_SPEC" ] ;  then
        message "Device $_DEV already attached to volume $_SPEC" ;
     elif [ -n "$_ATTACHED" ] ; then 
        error "Device $_DEV already attached to volume $_ATTACHED" ; 
     else
        attach-volume $_SPEC $_DEV 
     fi
   ;;
# Create a volume from snapshot , size , type encrypted 

# size 
[1-9]*)
  if [ -n "$_ATTACHED" ] ; then
    message "Device $_DEV already attached to $_ATTACHED - ignoring"
  else
    :; _size=$_SPEC
    message "Creating standard volume size $_size"
    aws ec2 create-volume --availability-zone $MARKLOGIC_ZONE --size $_size  \ 
        --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=$_VOLNAME}]" >{_vol} || 
        error "Error creating volume with size $_size."
    _id=$(echo "$_vol" | jsonpath '$.VolumeId')
    tag-ebs-volume $_id $_DEV
    wait-attach $_id $_DEV
  fi
  ;;
# Full specification
# [snapshot-id]:[volume-size]:[delete-on-termination]:[volume-type[:iops][:throughput]]:[encrypted]
snap-*:*:*:* | *:[1-9]*:*:*:* )
  if [ -n "$_ATTACHED" ] ; then
    message "Device $_DEV already attached to $_ATTACHED - ignoring"
  else
    message "Creating EBS volume size from specification: $_SPEC"
    # delete-on-termination is not used
    # encrypted is controlled by $MARKLOGIC_EBS_KEY
    if [ -z "$MARKLOGIC_EBS_KEY" ]; then
      # no encrypt
      MARKLOGIC_EBS_KEY=""
    fi
    _specs=<[ fn:tokenize($_SPEC, ':') ]>
    message "After tokenization: Specification = $_specs "
    if [ -n "${_specs[1]}" ]; then
      _snapshot_id='--snapshot-id'
    fi
    if [ -n "${_specs[2]}" ]; then
      _size='--size'
    fi
    if [ -n "${_specs[4]}" ]; then
      _volume_type='--volume-type'
    fi
    if [ -n "${_specs[4]}" ] && [ -n "${_specs[5]}" ] && [ "${_specs[4]}" = 'io1' ]; then
      _iops='--iops'
    fi
    if [ -n "${_specs[4]}" ] && [ -n "${_specs[5]}" ] && [ "${_specs[4]}" = 'gp3' ]; then
      _iops='--iops'
      message "Adding iops for gp3 volume type"
    fi
    if [ -n "${_specs[4]}" ] && [ -n "${_specs[6]}" ] && [ "${_specs[4]}" = 'gp3' ]; then
      _throughput='--throughput'
      message "Adding throughput for gp3 volume type"
    fi
    if [ -n "$MARKLOGIC_EBS_KEY" ]; then
      _encrypted='--encrypted'
      if [ "$MARKLOGIC_EBS_KEY" != 'default' ]; then
        _kms_key_id_opt="--kms-key-id"
        _kms_key_id="$MARKLOGIC_EBS_KEY"
      fi
    else
      _encrypted='--no-encrypted'
    fi
    aws ec2 create-volume \
      $_snapshot_id ${_specs[1]} \
      $_size ${_specs[2]} \
      $_volume_type ${_specs[4]} \
      $_iops ${_specs[5]} \
      $_throughput ${_specs[6]} \
      $_encrypted \
      $_kms_key_id_opt $_kms_key_id \
      --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=$_VOLNAME}]" \
      --availability-zone $MARKLOGIC_ZONE >{_vol} || error "Error creating volume with spec $_SPEC."
    _id=$(echo "$_vol" | jsonpath '$.VolumeId')
    tag-ebs-volume $_id $_DEV
    wait-attach $_id $_DEV
  fi
;;
  
# compatibilty just snapshot 
snap-* )
  if [ -n "$_ATTACHED" ] ; then
    message "Device $_DEV already attached to $_ATTACHED - ignoring"
  else 
    _snapshot_id="$_SPEC"
    aws ec2 create-volume --availability-zone $MARKLOGIC_ZONE --snapshot-id $_snapshot_id  \
      --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=$_VOLNAME}]" >{_vol} || 
      error "Error creating volume with snapshot $_snapshot_id."
    _id=$(echo "$_vol" | jsonpath '$.VolumeId')
    message "Created volume $_id from snapshot $_SPEC"
    tag-ebs-volume $_id $_DEV
    wait-attach $_id $_DEV
  fi
;;
 
 
*) error "Unknown volume specification: $_SPEC" ;;
esac

exit 0
