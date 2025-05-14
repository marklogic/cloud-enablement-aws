# Copyright (c) 2020 MarkLogic Corporation 
#######
##  SimpleDB MDB Functions
log "loading sdb-functions"


##
## sdb-   functions
##
MDB_DESC="SimpleDB Domain"

# sdb-trace $0 return-value ...
# returns with $2
function sdb-trace()
{
   trace-return $@
}



function sdb-domain-exists() {
     local _domain=$1
     local _out
     local _err
     aws:sdb-query -c "SELECT count(*) FROM `$_domain` LIMIT 1" >{_out} (error)>{_err} ||
       sdb-trace $@ $_false output: {$_out} error: ${_err}
}

function sdb-select-where()
{
    local _select="$1"
    local _where="$2"
    local _domain=$MDB_NAME
    return sdb-query( "SELECT $_select FROM `$_domain` where $_where"  )
}





## Local query function
_sdb_to_mdb_query=<{{
     declare variable $items external ;
     declare function local:attr( $a as element(attribute) ) as element() {
       let $name := $a/@name/string()
       return
       if( $name eq "device" ) then
       <devices> {
         let $devs :=  fn:tokenize(string($a) , ",")
             return
                  <device>
                     <ebs>{$devs[1]}</ebs>
                    <devid>{$devs[2]}</devid>
                    <volume>{$devs[3]}</volume>
                    <mount>{$devs[4]}</mount>
                   </device>
       } </devices>
       else
         element { fn:QName("", $a/@name ) } { $a/string() }
    };
    declare function local:item( $item as element(item) ) as element(item) {
     <item name="{$item/@name}"> {
         for $a in $item/attribute  return
         try {
           local:attr($a)
         } catch * {
             fn:trace( $a , "Failed creating element from attribute." )
         }
     }
     </item>
    };
    for $item in $items
    return
      typeswitch( $item )
      case element(item) return local:item( $item )
      case document-node() return for $i in $item//item return local:item( $i )
      default return <item name="error"> { fn:trace( $item , "Failed creating element from attribute." ) }</item>

   }}>

function sdb-items-to-mdb() {
   local _items=($@)
   local _mdb
   if xquery -n -q {$_sdb_to_mdb_query} -v  items {$_items} >{_mdb} ; then 
     return $_mdb
   else
     trace $0 "Error parsing SDB item" $_items result: $_mdb
     return $_empty 
   fi
}

function sdb-query()
{
   trace  $0 $@
   local _r
   if  aws:sdb-query -c "$@" >{_r}  ; then 
     return sdb-items-to-mdb( <[ $_r//item ]> )
   else
    trace $0 failed result: {$_r}
    return $_empty
  fi

}



#####################################
## mdb-   functions
##


# Update an existing record or add a new one
## mdb-update attr value ... 
function mdb-update()
{
   requiredn $0 2 $# attr value..
   local _key="$MDB_NODE_NAME"
   local _out
   local _err
   aws:sdb-put-attributes -r "$MDB_NAME" "$_key" "$@" >{_out} (error)>{_err} ||
     sdb-trace $0 $_false out: $_out err: $_err
}

# specifically create a new item
##  mdb-create-item attr value ... 
function mdb-create-item()
{
   mdb-update $@
}


# Delete the entire item/row
function mdb-delete-item()
{
   local ITEM="$MDB_NODE_NAME"
   local _out
   local _err
   aws:sdb-delete-attributes "$MDB_NAME" "$ITEM" >{_out} (error)>{_err} ||
     sdb-trace $0 $_false out: $_out err: $_err
}

function mdb-delete-attributes()
{
   local ITEM="$MDB_NODE_NAME"
   local _out
   local _err
   aws:sdb-delete-attributes "$MDB_NAME" "$ITEM" "$@" >{_out} (error)>{_err} ||
        sdb-trace $0 $_false out: $_out err: $_err
}
function mdb-update-instance-state()
{
###
###  Appears to be dead code
###
   if [ $# -gt 1 ] ; then
     local _a=mdb-get-attributes-from-instance( $1 )
     local _tm=mdb-get-attribute( $_a "instance-time" )
     local _n=mdb-get-attribute( $_a node)
     local _err;

   # Keep quiet this is run every minute
   #message "Updating instance state to running for $1 to $2"

     aws:sdb-put-attributes -update instance-time -exists $_tm "$_CLUSTER" "$_n" instance-state $2  >{_err} ||
       message "Failed to update instance state - time changed"

   else
    # message "Updating instance state to running for $MARKLOGIC_INSTANCE"
     mdb-update state-instance $MARKLOGIC_INSTANCE instance-state running instance-time <[ fn:current-dateTime() ]> ||
       message "Failed to update instance state"
  fi
}


# returns <item>* for all nodes
function mdb-get-attributes-for-node()
{
   [ $# -eq 1 ] || error "mdb-get-attributes-for-node: expected argument node-name"
   local _ITEM="$1"
   local _a
   aws:sdb-get-attributes -c "$MDB_NAME" "$_ITEM"  >{_a} ||
        return sdb-trace( $0 {$_empty} $@ result {$_a} )
   return sdb-items-to-mdb( <[ $_a//item ]> )
}



function mdb-get-master-hostname()
{
    local result=sdb-query( "SELECT host  from `$MDB_NAME` WHERE master='1'" )
    return mdb-get-attribute( $result "host" )
}

function mdb-get-master-nodename()
{
   local result=sdb-query( "SELECT node  from `$MDB_NAME` WHERE master='1'" )
    return mdb-get-attribute( $result "node" )
}

function mdb-get-master-instance()
{
    local result=sdb-query( "SELECT host,instance  from `$MDB_NAME` WHERE master='1'" )
    return mdb-get-attribute( $result "instance" )
}

function mdb-get-master-state()
{
    local result=sdb-query(  "SELECT state from `$MDB_NAME` WHERE master='1'" )
    return mdb-get-attribute( $result "state" )
}
function mdb-get-attributes-from-instance()
{
   return sdb-query( "SELECT * from `$MDB_NAME` WHERE instance='$1'" )
}

function mdb-delete-domain()
{
  aws:sdb-delete-domain "$MDB_NAME"  ||
    sdb-trace $0 $_false
}

function mdb-get-all-items()
{
   return sdb-query(  "SELECT * FROM `$MDB_NAME`" )
}



# Return host,instance,master attributes
function mdb-get-all-hosts() {
   return sdb-query( "SELECT host,instance,master from `$MDB_NAME` ")
}

function mdb-get-index-in-zone()
{
    required $0 zone $@
    local _z="$1" 
    local _items=sdb-query( "SELECT index FROM `$MDB_NAME` where zone = '$_z'" )
    return <[ ($_items/index/xs:integer(.)) ]>
}

# mdb-add-device-entry ebs-vol  ebs dev volid mount
function mdb-add-device-entry()
{
  mdb-validate-device-entry $@  ||  trace-return $0 $_false "Device entry already exists in MDB"
  aws:sdb-put-attributes +r "$MDB_NAME" "$MDB_NODE_NAME" device "$1,$2,$3,$4"  >/dev/null ||
    sdb-trace $0 $_false $@
}
#   mdb-update-if-equals Key attribute expected-value attr value [attr value ..]
#  Update only if attribute ($2) exists and has value ($3)
function mdb-update-if-equals()
{
  [ $# -gt 3 ] || error "mdb-update-if-equals: expected arguments key attribute expected-value attr value [attr value ..]"
  local _N="$1"
  local _aname="$2"
  local _avalue="$3"
  shift 3
  # node is both the 'invisible key name' and a seperate field
  aws:sdb-put-attributes -update "$_aname" -exists "$_avalue" "$MDB_NAME" "$_N" node "$_N" $@ >/dev/null (error)>/dev/null ||
    sdb-trace $0 $_false $@
}


# mdb-allocate-node  NodeName instance zone [ extra ]
  #  IF node slot doesnt exist, or is my instance and node
function mdb-allocate-node()
{

  requiredn $0 3 $# node instance zone
  local _N="$1"
  local _inst="$2"
  local _zone="$3"
  trace $0 node "$_N" instance "$_inst" zone "$_zone"
  shift 3
  local _err1
  local _err2
  shift
  # try to put only if slot doesnt exist
  # insert record (key ==node) if node does not exist
  #  OR
  # update record if instance exists and = $INSTANCE
  local _dt=<[ fn:current-dateTime() ]>
  local _attrs=( node "$_N" create-date $_dt  instance "$_inst"  zone "$_zone" )
  if aws:sdb-put-attributes -update node "$MDB_NAME" "$_N"  $_attrs $@ >{_err1} ||
    aws:sdb-put-attributes -update instance -exists "$_inst" \
       "$MDB_NAME" "$_N"   $_attrs $@ >{_err2}  ; then
             message "Allocated Node $_N"
             sdb-trace $0 $_true $@ err1: $_err1 err2 $_err2 
             return $_true ;
   fi
   sdb-trace $0 $_false $@ err1: $_err1 err2 $_err2
   return $_false
}


# Query if a MDB 'domain' (SDB Domain or DDB Table) exist
function mdb-domain-exists() {
      sdb-domain-exists "$@"
}



