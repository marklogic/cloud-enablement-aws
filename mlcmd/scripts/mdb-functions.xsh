# Copyright (c) 2020 MarkLogic Corporation 
# Metadata Functions
[ -n "$_MDB_FUNCTIONS_INIT" ] && return 0

trace $0 "loading mdb-functions"

####  Common funnctions


## Must NOT call any message code in this block until we get the MDB type defined
function init-mdb-type()
{
  trace $0
  if [ -z "$_MDB_TYPE" ] ; then
      trace $0 "Detecting MDB Type"
      trace $0 MARKLOGIC_MDB_TYPE=$MARKLOGIC_MDB_TYPE $MARKLOGIC_DDB_TABLE=$MARKLOGIC_DDB_TABLE
      trace $0 MARKLOGIC_SDB_DOMAIN=$MARKLOGIC_MARKLOGIC_SDB_DOMAIN MARKLOGIC_CLUSTER_NAME=$MARKLOGIC_CLUSTER_NAME
      [ -z "$_MDB_TYPE" -a -n "$MARKLOGIC_MDB_TYPE" ]   && _MDB_TYPE="$MARKLOGIC_MDB_TYPE"
      [ -z "$_MDB_TYPE" -a -n "$MARKLOGIC_DDB_TABLE"  ] && _MDB_TYPE=ddb
      [ -z "$_MDB_TYPE" -a -n "$MARKLOGIC_SDB_DOMAIN"  ] && _MDB_TYPE=sdb
      [ -z "$_MDB_TYPE" -a -n str:contains( $MARKLOGIC_CLUSTER_NAME "DDBTable" )  ] && _MDB_TYPE=ddb
      [ -z "$_MDB_TYPE" -a -n str:contains( $MARKLOGIC_CLUSTER_NAME "SDBDomain" )  ] && _MDB_TYPE=sdb
    fi
    if [ -z "$_MDB_TYPE" ] ; then
       log "No MDB type detected - defaulting SimpleDB"
       logger -t MarkLogic "No MDB type detected - defaulting SimpleDB"
       _MDB_TYPE="sdb"
    fi
    mdb-type-valid  || error "Invalid MDB type detected - aborting. MDB type: " $_MDB_TYPE
    trace $0 _MDB_TYPE=$_MDB_TYPE
}

function mdb-type-valid()
{
  trace-return $0 str:is-one-of( "$_MDB_TYPE" sdb ddb ) 
}

function mdb-valid()
{
  trace $0  _MDB_TYPE=$_MDB_TYPE  MDB_NAME=$MDB_NAME
  mdb-type-valid && ! [ str:is-blank( $MDB_NAME ) ]
}


# TEMP: opt for sdb
function mdb-is-sdb()
{
   trace-return $0 str:is-equal( "$_MDB_TYPE" sdb )
}

function mdb-is-ddb()
{
   trace-return $0 str:is-equal( "$_MDB_TYPE" ddb )
}

##
## Attribute functions
## mdb-attr-value( node )                   - takes an attribute node and extracts the value
## mdb-attr-xxx( [value] )            - takes a single attrubute or () and casts it to the type
## mdb-get-attr-xxx( $results name )  - takes a result node, extracts the attribute a
##                                      and casts it to the type
## mdb-get-attribute( $results name )      - takes the result node and extracts the attribute value

# Gets the value given an attribute element or item element and name
function mdb-attr-value() {
   log mdb-attr-value $@
   [ $# -ne 1 ] && return $_null
   local _item=$1

   return <[
       typeswitch( $_item )
       case element()   return
                  $_item/fn:data()
       case document-node()  return
                  $_item/*/fn:data()
       default return fn:string( $_item )
     ]>
   }


function mdb-get-attr-value() {
   log mdb-get-attr-value $@
   [ $# -ne 2 ] && return $_null
   local _item=$1
   local _name="$2"
   return <[
       typeswitch( $_item )
       case element()    return
              $_item/*[local-name(.) eq $_name]/fn:data()
       case document-node()  return
             $_item/*/*[local-name(.) eq $_name]/fn:data()
       default return fn:trace( () , concat("unexpected element type for mdb-attr-value: " , string($_item)) )
     ]>
}




function mdb-attr-string() {
    [ $# -ne 1 ] && return $_null
    local _value=mdb-attr-value( $@ )
    return <[ fn:normalize-space( $_value ) ]>
}
function mdb-get-attr-string() {
   return mdb-attr-string( mdb-get-attr-value( $@ ) )
}

# get attribute as xs:dateTime or null - log error on cast problem
function mdb-attr-datetime() {
    [ $# -ne 1 ] && return $_null
    local _value=mdb-attr-value($@)
    return <[
       if( $_value castable as xs:dateTime )
          then  xs:dateTime($_value)
      else
         fn:trace( ()  , concat("Value is not castable to xs:dateTime: " , string($_value) ) )
       ]>
}

# get attribute as xs:dateTime or null - log error on cast problem
function mdb-get-attr-datetime() {
    [ $# -ne 2 ] && return $_null
    return mdb-attr-datetime( mdb-get-attr-value($@) )
}

# Get an attribute value from a result + name
#
function mdb-get-attribute() {
  # protect against null result object which is valid
  [ $# -ne 2 ] && return $null
  return mdb-get-attr-value( $@ )
 }




function mdb-attr-blank() {
    [ $# -ne 2 ] && return $_true
    local _value=mdb-get-attribute($@)
    return <[  string-length(normalize-space($_value)) eq 0 ]>
}

# Normalize the <attribute> format the structured item
function mdb-node-state() {
   local item=mdb-get-attributes()
   return <[ ($item/state/string(),"_init")[.][1] ]>
}

function mdb-hostid() {
   local item=mdb-get-attributes()
   return  mdb-get-attr-string( $item  hostid )
 }



function mdb-host() {
   local item=mdb-get-attributes()
   return mdb-get-attr-string( $item host )
}
# Does the 'item' a
function mdb-item-exists() {
   local item=mdb-get-attributes()
   return  <[ exists($item/*) ]>
}
# returns a sequence of device nodes
# If called with 0 args then fetches from mdb
function mdb-get-devices()
{
  trace $0 
  local _mdb
  if [ $# -eq 0 ] ; then 
    _mdb=mdb-get-attributes()
  else
     _mdb=$1
  fi
  return <[ $_mdb//devices/device ]>
}

function mdb-get-device()
{
  local _mdb=$1
  local _dev=$2
  return <[
    $_mdb//devices/device[ ebs eq $_dev ]
  ]>
}
function mdb-get-device-mount()
{
  local _dev=mdb-get-device( $1 $2 )
  return mdb-attr-string(<[ $_dev/mount  ]>)
}

# Returns the <item> recored for our node
function mdb-get-attributes()
{
   return mdb-get-attributes-for-node($MDB_NODE_NAME)
}


## check to see if there are any device entries for this record
function mdb-has-device-entries()
{
   local _a=mdb-get-attributes() 
   return <[ exists( $_a//device ) ]> 
}

# mdb-valid-device-entry ebs-vol  ebs dev volid mount
function mdb-validate-device-entry()
{
  requiredn $0 4 $# ebs dev volid mount
  local _devices=mdb-get-devices()
  local _ebs=$1
  local _dev=$2
  local _volid=$3
  local _mount=$4
  local _matches=<[ $_devices[ ($_ebs = ebs) or
               ($_volid = volume ) or
               ($_mount eq mount ) ] ]>
  [ <[ empty( $_matches ) ]> ] && return $_true
  #validating only volume id, ebs and mount, since devid in nvme mapping differs after reboot
  local _conflicts=<[ $_matches except $_matches[
           ( volume eq $_volid ) and
           ( ebs  eq $_ebs ) and
           ( mount eq $_mount ) ] ]>
   
  if [ <[ exists($_conflicts) ]> ] ; then 
     error "New device entry conflicts with existing entry"  {$_conflicts}
     return $_false 
  fi
  trace-return $0  $_false
  
}   

function mdb-get-master()
{
# TODO Change to querying from system
  if is-master ; then
     return $MARKLOGIC_HOSTNAME
  else
    return mdb-get-master-hostname()
  fi
}


function mdb-update-state()
{
   message "Updating state for $MARKLOGIC_INSTANCE to $1"
   mdb-update state $1 state-instance $MARKLOGIC_INSTANCE instance-state running instance-time <[ fn:current-dateTime() ]>
}

init-mdb-type


if mdb-is-sdb ; then
  trace $0 "Loading sdb functions"
  . sdb-functions
elif mdb-is-ddb ; then
  trace $0 "Loading ddb functions"
  . ddb-functions
else
  error "SNH: Managed cluster with No MDB type found - aborting"
fi



_MDB_FUNCTIONS_INIT=1

