
# common functions
# Copyright (c) 2022 MarkLogic Corporation
[ -n "$_FUNCTIONS_INIT" ] && return 0

import commands xs=xs
import commands posix
import commands str=string
declare namespace h=http://marklogic.com/manage/hosts
declare namespace m="http://marklogic.com/manage"
declare namespace d="http://marklogic.com/xdmp/database"
declare namespace a="http://marklogic.com/xdmp/assignments"



_ec2_instances=()
_ec2_instances_dt=()

 ## constants
 _false=<[ fn:false() ]>
 _true=<[ fn:true() ]>
 _null=<[ () ]>
_empty=<[ () ]>

# avoid recursion in message
_message=$_false


# Trace logging for debugging
# trace $0 ...
# returns with the previous $?
function trace() {
  local _e=$?
  local _n=$1
  shift
  log -c mlcmd.trace  -p trace  ${_n}: exit-status: $_e args: $@ 
  return $_e
}
# tracereturn $0 return-value ...
# returns with $2
function trace-return()
{
  local _e=$?
  local _n=$1
  local _r=$2
  shift 2
  log -c mlcmd.trace  -p trace  ${_n}: exit-status: $_e return: ${_r} args: $@ xlocation()
  return $_r
}

function is-blank()
{
   [ $# -lt 1 -o -z "$1" ]
}

#requiredn name nargs $#  [name1 ... ]
function requiredn()
{
   [ $# -lt 3 ] && error "$0: $_1 missing required arguments"
   [ "$3" -ge "$2"  ] && return 0
   local _func=$1
   shift 3
   error "$_func: missing required args $*"

}
#required name argname argvalue ...
function required()
{
   [ $# -lt  1 ] && error "$0: missing required arguments."

   local _func=$1
   shift
   [ $# -lt  2 ] && error "$_func: missing required argument: $1"
   return 0
}


ec2-describe-instances()
{
  if [ <[  empty($_ec2_instances)
        or empty( $_ec2_instances_dt )
        or  $_ec2_instances_dt lt (fn:current-dateTime() - xs:dayTimeDuration("PT30S") ) ]> ]; then
     aws:ec2-describe-instances -rate-retry 10 >{_ec2_instances}
     _ec2_instances_dt=<[ fn:current-dateTime() ]>
  fi

  if [ $# -gt 0 ] ;  then
    local id=$1
    return <[ $_ec2_instances//instance[@instance-id eq $id] ]>
  else
    return $_ec2_instances
  fi
}




# getopt( $_options optname global default ).
function getopt()
{
   requiredn $0 2 $# opts optname glob [def]
   local _opts=$1
   local _optname=$2
   shift 2;
   local _defs=$@
   return <[ ($_opts//option[@name eq $_optname]/string(),$_defs)[.][1] ]>

}
function hasopt()
{
   local _opts=$1
   local _optname=$2
   return <[ exists($_opts//option[@name eq $_optname]) ]>
}
#
#
#
# usage
function usage()
{
  error "usage: $@"
}

function error()
{
    if $_message ; then
      log "error during message logging ignored" $@
      return $_true
    fi
    message "$@"
    exit 1
}


function message()
{
## Only use builtins at this point
    if $_message ; then
       log  "Unexpected error recursing in message function - " $@
       logger -t "Unexpected error recursing in message function - " $@
       _message=$_false
       return $_true
    fi


    local _title="$1"
    shift
    local _args="$*"
    echo -p error -- $_title
    logger -t MarkLogic -- "$_title"
    [ -n "$_args" ] && echo -p error -- "$_args"
    [ -n "$_args" ] && logger -t MarkLogic -- "$_args"

# Avoid error recursion
    _message=$_true
    # If we are recursing in message stop here
    if [ -n "$MARKLOGIC_LOG_SQS" -a "$MARKLOGIC_LOG_SQS" != "none" ] || [ -n "$MARKLOGIC_LOG_SNS" -a "$MARKLOGIC_LOG_SNS" != "none"   ]  ; then
      local _i=$INSTANCE
      C="$MARKLOGIC_CLUSTER_NAME"
      [ -z "$_i" ] && _i=$MARKLOGIC_INSTANCE
      local _c=<[ replace($C,'-[^-]+$','') ]>
      local _c=<[ replace($_c,'-MarkLogicSDBDomain$','') ]>
      local _nc=$MARKLOGIC_NODE_NAME
      local _nm=$MDB_NODE_NAME
      local _h=$MARKLOGIC_HOSTNAME
      local _sdb=""
      mdb-valid && _sdb=mdb-get-all-items()

      local _msg=<[
        try {
           <log message_dt="{ current-dateTime()}"
                system="mlcmd"
                instance="{$_i}"
                cluster="{$_c}"
                node="{$_nm}"
                node-config="{$_nc}"
                host="{$_h}">
                <title>{ $_title}</title>
                <body>{$_args}</body>
                <sdb>{$_sdb}</sdb></log>
          } catch * {
            <log message_dt="{ current-dateTime()}"
                system="mlcmd" ><title>Error creating message</title></log>
          }
          ]>
      [ -n "$MARKLOGIC_LOG_SQS" ] && aws:sqs-send-message "$MARKLOGIC_LOG_SQS" <{_msg}  >/dev/null 2>&1
      [ -n "$MARKLOGIC_LOG_SNS" ] && aws:sns-publish -t "$MARKLOGIC_LOG_SNS" -m {$_msg} -s "MarkLogic startup message"   >/dev/null 2>&1
    fi
 _message=$_false

}

function sleep-random()
{
   local _r=$RANDOM
   local _min=$1
   local _max=$2
   local _msg=""
   [ $# -gt 2 ] && _msg=$3
   local _t=<[  xs:int($_r) mod (xs:int($_max) - xs:int($_min)) + 1 + xs:int($_min) ]>
   message "Sleeping for $_t seconds" $_msg
   sleep $_t
}


# is-managed
# returns true if this is a managed node
function is-managed() {
 [ -n "$MARKLOGIC_CLUSTER_NAME" -a -n "$MARKLOGIC_NODE_NAME"  ]
}

# is-autocreate
# returns true if configured for autocreate of initial user
# AWS MarketPlace feature
function is-autocreate() {
#  message "is-autocreate MARKLOGIC_ADMIN_AUTOCREATE=$MARKLOGIC_ADMIN_AUTOCREATE"
  ! [ -n "$MARKLOGIC_CLUSTER_NAME" -a -n "$MARKLOGIC_NODE_NAME" ] &&
    [ -n "$MARKLOGIC_ADMIN_AUTOCREATE" -a -n "$MARKLOGIC_ADMIN_USERNAME" ]
}

function is-managed-or-autocreate()
{
   is-managed || is-autocreate

}

assert-managed-or-autocreate()
{
  is-managed-or-autocreate || error "Not a managed node or configured for Automatic User Creation"
}


function assert-autocreate() {
  is-autocreate || error "Not configured for Automatic User Creation"
}
function is-master() {
  [ "$MARKLOGIC_CLUSTER_MASTER" = 1 ]
}

function assert-managed() {
  is-managed || error "Not a managed node"
}

function is-authenticated() {
 [ -n "$MARKLOGIC_ADMIN_USERNAME" -a -n "$MARKLOGIC_ADMIN_PASSWORD" ]
}

function assert-authenticated() {
  is-authenticated || error "Authentication requires MARKLOGIC_ADMIN_USERNAME and MARKLOGIC_ADMIN_PASSWORD"
}


# Given a string like A,B or A,B,*  return the indexed (1 basd) item
# If the last item in the list is "*" and the index is >= that item then reurns the last non-* item

function get-indexed-value() {
   [ $2 -lt 1 ] && return $1
   local _value=$1
   local _index=xs:integer($2)
   return <[
     let $vs := tokenize($_value,","),
         $star := $vs[last()] eq "*",
         $vs := if( $star ) then $vs[ position() < last() ] else $vs ,
         $val := $vs[$_index]
     return
         if( empty($val) and $star ) then
           $vs[last()]
         else
           $val
  ]>

}


#
# ec2 specific functions
#

import module aws=aws

function instance-state() {
  local id=$1
  local instance=ec2-describe-instances($id)
  return <[ $instance/@state/string() ]>
}

# bug:56218 55780 57705
function terminate-instance() {
  local id=$1
  local term_response=$<(aws:ec2-terminate-instances -rate-retry -10 $id)
  message "Instance termination response: $term_response"
  return 0
}

function instance-is-alive() {
  local _state=instance-state( $1 )
  return <[ $_state = "running" ]>
}

function image-state() {
  local r=$1
  local id=$2
  local image=$<(aws:ec2-describe-images -rate-retry 10 -region $r $id)
  return <[ $image//image/@state/string() ]>
}

function volume-state()
{
  required $0 id $1
  local id=$1
  local image=$<(aws:ec2-describe-volumes -rate-retry -10 $1)
  return <[ $image//volume/@state/string() ]>
}


function wait-for-instance-state()
{
   required $0 id $1 states $2
   local id=$1
   local states=$2
   message "Waiting for instance to startup: $id in states $states"
   local count=<[ 0 ]>
   while sleep 30 ; do
      local state=instance-state( $id )
      message "Instance $id State $state"
      if [ <[ $state = ($states ) ]>  ] ; then
        return $state
      fi
      count=<[ $count + 1 ]>
      if [ $count -gt 100 ] ; then
        message "Gave up waiting for Instance $id State $states"
        exit 1
      fi
   done
}



function wait-for-image-state()
{
  required region id states $@
   local r=$1
   local id=$2
   local states=$3
   message "Waiting for image to complete: $id in states $states"
   local count=<[ 0 ]>
   while sleep 30 ; do
      local state=image-state( $r $id )
      message "Image $id State $state"
      if [ <[ $state = ($states ) ]>  ] ; then
        return $state
      fi
      count=<[ $count + 1 ]>
      if [ $count -gt 100 ] ; then
        message "Gave up waiting for image $id State $state"
        return "_invalid"
      fi
   done
}



function wait-for-volume-state()
{
   local id=$1
   local states=$2
   message "Waiting for volume to complete: $id in states $states"
   local count=<[ 0 ]>
   while sleep 5 ; do
      local state=volume-state( $id )
      message "Volume $id State $state"
      if [ <[ $state = ($states ) ]>  ] ; then
        return $state
      fi
      count=<[ $count + 1 ]>
      if [ $count -gt 100 ] ; then
        message "Gave up waiting for volume $id State $states"
        return "_invalid"
      fi
   done
}


function is-device-attached()
{
  local _vol=$1
  local ec2=ec2-describe-instances( $MARKLOGIC_INSTANCE )
  return <[ $ec2//device[@name eq $_vol]/@volume-id/string()  ]>
}

function get-ebs-volume-id()
{
  local _dev=$1
  local ec2=ec2-describe-instances( $MARKLOGIC_INSTANCE )
  return <[ $ec2//device[@name eq $_dev]/@volume-id/string() ]>
}

function get-ebs-devices()
{
  local _devs=($*)
  local ec2=ec2-describe-instances( $MARKLOGIC_INSTANCE )
  if [ $# -eq 0 ] ; then
        return <[ $ec2//device ]>
  else
        return <[ $ec2//device[@name = $_devs] ]>
  fi
}

# tag-ebs-volume id device
function tag-ebs-volume()
{
  local _id=$1
  local _DEV=$2
  local _tags=get-ec2-tags()
  local _etags=<[
     for $t in $_tags
     return ("-tag" , concat( "marklogic:" , replace($t/@key , "^aws:","" )  , "=" , $t/@value ) )
  ]>

   message "Adding extra tags to volume $_id"  $_etags

   aws:ec2-create-tags -tag "marklogic:instance=$MARKLOGIC_INSTANCE" -tag "marklogic:device=$_DEV" \
           -tag "marklogic:cluster=$MARKLOGIC_CLUSTER_NAME" -tag "marklogic:node=$MDB_NODE_NAME" \
           $_etags \
           $_id
}

# Get the tags of an ebs volume
function get-ec2-tags()
{
  local ec2=ec2-describe-instances( $MARKLOGIC_INSTANCE )
  return <[ $ec2//tags/tag ]>
}

# gets the os device name from the ebs device name
function get-os-device-name()
{
   local ostype=get-ostype()
   local instancetype=`ec2-get-meta instance-type`
   local devices
   xread devices < $MLCMD_HOME/conf/ebs-devices.xml
   local names=($*)

   if [ $# -eq 0 ] ; then
     return <[
          ($devices/devices/platform[ @os eq $ostype ]/device/instance[matches($instancetype,@family)]/@device/string())[1]
     ]>
   else
     return <[
          ($devices/devices/platform[ @os eq $ostype ]/device[@name = $names]/instance[matches($instancetype,@family)]/@device/string())[1]
     ]>
   fi
}

# gets the os mountpoint name from the ebs device name
function get-os-mountpoint()
{
   local ostype=get-ostype()
   local devices
   xread devices < $MLCMD_HOME/conf/ebs-devices.xml
   local names=($*)

   if [ $# -eq 0 ] ; then
     return <[ $devices/devices/platform[ @os eq $ostype ]/device/@mountpoint/string() ]>
   else
     return <[ $devices/devices/platform[ @os eq $ostype ]/device[@name = $names]/@mountpoint/string() ]>
   fi
}


# Get the ebs device name from index (1 = /dev/sdf)
function get-ebs-device-name()
{
   local ostype=get-ostype()
   local devices
   xread devices < $MLCMD_HOME/conf/ebs-devices.xml
   local index=$1

   if [ $# -eq 0 ] ; then
     return <[ $devices/devices/platform[ @os eq $ostype ]/device/@name/string() ]>
   else
     return <[ $devices/devices/platform[ @os eq $ostype ]/device[xs:int($index)+1]/@name/string() ]>
   fi
}

function get-default-fstype()
{
   local ostype=get-ostype()
   local devices
   xread devices < $MLCMD_HOME/conf/ebs-devices.xml

   return <[ $devices/devices/platform[ @os eq $ostype ]/@fstype/string() ]>
}


function get-ostype()
{
   if [ -f /etc/redhat-release ] && [ -e /dev/xvde1 -o -e /dev/xvde  ] ; then
      return redhat
   elif [ -f /etc/SuSE-release ] ; then
      return suse
   else
      return linux
   fi
}


function get-hosts-with-security()
{
  xread db < $MARKLOGIC_DATA_DIR/databases.xml
  xread as < $MARKLOGIC_DATA_DIR/assignments.xml

  sec_forests=<[ $db//d:database[d:database-name eq "Security"]/d:forests/d:forest-id/string() ]>

  hosts=()
  for s in $sec_forests  ; do
    primary=<[ $as//a:assignment[a:forest-id eq $s] ]>
    host=<[ $primary/a:host/string() ]>
    hosts+=$host
    for r in <[ $primary/a:forest-replicas/a:forest-replica/string() ]> ;  do
      h=<[ $as//a:assignment[a:forest-id eq $r]/a:host/string() ]>
     hosts+=$h
    done
  done
  return $hosts
}




function wait-for-master()
{
   message "Waiting for master node to come online"
   while true ; do



      local _master=mdb-get-master-instance();
      if [ -z "$_master" ] ; then
          message "No master host started yet - waiting" ;
          sleep-random 30 60 "wait-for-master";
          continue ;
      fi
      if ! instance-is-alive $_master ; then
          messsage "Instance: $_master is not currently running - waiting"
          sleep-random 30 60 "wait-for-master"
         continue
      fi
      local _state=mdb-get-master-state()
      if [ "$_state" != "initialized" ] ; then
          message "Master is not yet initialized - waiting" ;
          sleep-random 30 60 "wait-for-master";
          continue ;
      fi
     message "Master instance is online: $_master"
     break;
  done
  return 0
}

# Get an ordered list of hosts which are running starting with the master host
# Used for joining to the master where we dont have access to a local configuration
function get-joining-hosts()
{
  local all=mdb-get-all-hosts()
  local nodes;
  local n;
  local nodes=<[
     let $items := $all[node ne $MDB_NODE_NAME] ,
         $master := $items[ master eq '1' ]
         return ($master , $items except $master )
   ]>

  local ec2=ec2-describe-instances( <[ $nodes/instance/string() ]> ) || error "error describing ec2 instances" {$ec2}
  local good=( mdb-get-master() )
  for live in <[ $ec2[@state eq "running"]/@instance-id/string() ]> ; do
    local n=<[ $nodes[ instance eq $live]/host/string() ]>
    [ "$n" = "$MARKLOGIC_HOSTNAME" ] && continue  # extra paranoid
    good+=($n)
  done
  # return at most 3 hosts to try
  return <[ distinct-values($good)[ position() lt 4 ]  ]>
}


# Get an ordered list of hosts which are running ordered by hosts which have security forests but not including our host
# Used for renaming this host
function get-cluster-hosts()
{
  is-master && return localhost
  local all ;
  local _myhostid=mdb-hostid()
  local ret=()
  all=get-hosts-with-security()
  [ ${#all} -eq 0 ] && return $ret
  local _ids=<[ $all[ . != $_myhostid ] ]>
  [ ${#_ids} -eq 0 ] && return $ret
  items=mdb-get-all-items()
  local nodes=<[ $items[hostid = $_ids] ]>
  [ ${#nodes} -eq 0 ] && return $ret

  local ec2=ec2-describe-instances( <[ $nodes/instance/string() ]> ) || error "error describing ec2 instances" {$ec2}
  local good=()
  for live in <[ $ec2[@state eq "running"]/@instance-id/string() ]> ; do
    local n=<[ $nodes[ instance eq $live]/host/string() ]>
    [ "$n" = "$MARKLOGIC_HOSTNAME" ] && continue  # extra paranoid
    good+=($n)
  done
  return $good
}

# return true if Node name is a pattern spec
function is-node-pattern()
{
  return str:contains( "$1" '#' )
}
# returns the pattern part of a node patten ("#...")
function node-pattern-part()
{
   return str:substring-after( "$1" str:substring-before( "$1"  '#' ) )
}
function node-prefix-part()
{
   return str:substring-before( "$1"  '#' )
}

# localize-node-pattern str zone
# Take a node name and localize it by appending "-<zone>"
# If its a patterned name (ends with "#") then move the "#" to the end
# If already localized then return as-is
function localize-node-pattern()
{
    requiredn $0 2 $# nodename zone
    local n="$1"
    local z="$2"
    local s=""
    # split   prefix#pattern
    if is-node-pattern "$n" ; then
       s=node-pattern-part( $n )
       n=node-prefix-part( $n )
    fi
    # strip previous zone if any
    if [ str:ends-with( "$n" "-$z" ) ] ; then
       n=str:substring-before( "$n" "-$z" )
    fi
    return "$n-$z$s"
}
# replace-node-pattern( name  index )
function replace-node-pattern()
{
  requiredn $0 2 $# name index
  local p=node-prefix-part( $1 )
  return "$p$2"
}

# source the sdb or ddb function set
## ONLY if this is a managed cluster


if is-managed ; then 
  . mdb-functions
else
  trace $0 "Not loading mdb functions - not a managed cluster "
  
  
function mdb-valid() {
  return $_false ;
}



# TEMP: opt for sdb
function mdb-is-sdb()
{
   return $_false
}

function mdb-is-ddb()
{
   return $_false
}



fi

_FUNCTIONS_INIT=1
