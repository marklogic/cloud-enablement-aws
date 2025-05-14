# Copyright (c) 2020 MarkLogic Corporation 
#######
##  DynamoDB MDB Functions
log "loading ddb-functions"
## Primary Hash key is 'node'
_KEY_NAME="node"

##
## ddb-   functions
##
MDB_DESC="DynamoDB Table"


function ddb-trace()
{
   trace-return $@ ddb-error:  {$_ddb_error}
}

function ddb-condition-error()
{
  trace-return $@ ddb-condition-error: {$_ddb_error}

}


# create a key/value argument

function ddb-key()
{
  return aws:ddb-key(  "$_KEY_NAME" "$1" )
}

# Generate expression name placeholders for N names / exprs
# ddb-expr-names(  3 ) ->  ( "#n1","#n2" , "#n3" )
function ddb-expr-names()
{
   local _n=$1
   return <[ for $i in 1 to $_n return concat(  "#n" , string($i) ) ]>
}

# Generate expression value  placeholders for N names / exprs
# ddb-expr-names(  3 ) ->  ( ":v1",":v2" , ":v3" )
function ddb-expr-vnames()
{
   local _n=$1
   return <[ for $i in 1 to $_n return concat(  ":v" , string($i) ) ]>
}



# ddb-name-expr name [ name ... ]
# return ( attr-name-expr( "#name" : "name" ) ... )
function ddb-name-expr()
{
   local _expr
   local _names=ddb-expr-names( $# )
   for _n ; do
      local _ne=${_names[1]}
      shift _ne
      _expr=aws:ddb-attr-name-exprs(  $_expr  aws:ddb-attr-name-expr( "$_ne" "$_n" ) )
   done
  return $_expr
}
# ddb-value-expr name value [ name value .. ]
function ddb-value-expr()
{
   local _expr
   local _nargs=$#
   local _names=ddb-expr-vnames( <[ $_nargs idiv 2 ]> )
   while [ $# -ge 2 ] ; do
     local _n="$1"
     local _v=$2
     local _nv=${_names[1]}
     shift _names
    _expr=aws:ddb-attr-value-exprs( $_expr  aws:ddb-attr-value-expr( $_nv  $_v) )
    shift 2
   done
  return $_expr
}

# create a named attribute/value
# ddb-attr( expr )
# ddb-attr( name value
# ddb-attr( name type value )
function ddb-attr()
{
   [ $# -eq 0 -o $# -gt 3 ] && error "$0: unexpected arguments. Usage: $0( expr [,expr [,expr]])" xlocation()
   return aws:ddb-attribute( $@ )
}

# [OK]
function ddb-attrs-name-value()
{
   [ $# -eq 0 ] && return $_null
   local _attrs=
   while [ $# -ge 2 ] ; do
       _attrs=aws:ddb-attributes( $_attrs ddb-attr( $1 $2 ) )
       shift 2 ;
   done
   [ $# -gt 0 ] && error "$0: Unexpected remaining argurments" xlocation()
   return $_attrs
 }

# [OK]
# Basic update expression
# given Key . Value ... produce
# -update "SET key = value , .. " -attr-name-expr {name mappings} -attr-value-expr {expr-mapings}
 # Single SET/ADD/REMOVE expression
 function ddb-update-expr()
 {
   requiredn $0 3 $# "OP name value ..."
   local _op=$1
   shift
   unset _nexpr
   unset _vexpr
   local _nargs=$#
   local _nnames=<[ $_nargs idiv 2 ]>
   local _vnames=ddb-expr-vnames( $_nnames )
   local _nnames=ddb-expr-names( $_nnames )
   local _u=()
   while [ $# -ge 2 ] ; do
     local _n="$1"
     local _v=$2  # dont convert to string
     local _vn=${_vnames[1]}
     local _nn=${_nnames[1]}
     shift _vnames ; shift _nnames
     _nexpr=aws:ddb-attr-name-exprs(  $_nexpr  aws:ddb-attr-name-expr( $_nn "$_n" ) )
     _vexpr=aws:ddb-attr-value-exprs( $_vexpr  aws:ddb-attr-value-expr( $_vn  $_v) )
     _u+=( "$_nn = $_vn" )
     shift 2;
  done
  local _r=str:join(  "," $_u)
  return "$_op $_r"
 }


## Local query function
_ddb_to_mdb_query=<{{
     declare variable $items external ;
     (: primary key name - aka $_KEY_NAME :)
     declare variable $_keyname := "node" ;
     declare function local:attr( $a as element(attribute) ) as element() {
       let $name := $a/@name/string()
       return
       if( $name eq "device" ) then
       <devices> {
       
         for $v in $a/value 
         let $devs :=  fn:tokenize(string($v/string() ) , ",")
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
     let $key := $item/attribute[@name eq $_keyname ]
     return
       <item name="{$key/string()}"> {
         for $a in $item/attribute
         return
          try {
           local:attr($a)
         } catch * {
            <item name="error"> { fn:trace( $a , "creating attribute" ) }</item>
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

# [OK]
function ddb-items-to-mdb() {
   trace $0 
   local _items=($@)
   local _mdb
   unset _ddb_error
   #xecho $@ 1>&2
   xquery -n -q {$_ddb_to_mdb_query} -v  items {$_items} >{_mdb} (error)>{_ddb_error} ||
      return ddb-trace( $0 {$_empty} )
  return $_mdb
}

# [OK]
function ddb-table-exists() {
     required $0 table $@
     local _table=$1
     local _res;
     unset _ddb_error
     aws:ddb-describe-table  -table "$_table" >{_res} (error)>{_ddb_error} ||
        return ddb-trace( $0 $_false $@ result: $_res )
     return <[ exists( $_res//table[@name eq $_table] ) ]>
}

##
## Query over all tables using an index
##
function ddb-query()
{
  trace $0 $@
  local _res ;
  unset _ddb_error
  aws:ddb-query   -table "$MDB_NAME"  $@  >{_res} (error)>{_ddb_error} ||
        return ddb-trace( $0 {$_empty} $_res )
  trace-return $0 $_res
}


##
## Query over all tables without an index
##

function ddb-scan()
{
  local _res ;
  unset _ddb_error

   aws:ddb-scan  -table "$MDB_NAME"  $@  >{_res}  (error)>{_ddb_error}  ||
           return ddb-trace( $0 $_empty $_res )
  return ddb-items-to-mdb( <[ $_res//item ]> )
}



#####################################
## mdb-   functions
##



# Update an existing record for the current instance or add a new one
# [OK]
# mdb-update name value ..
function mdb-update
{
   trace $0 $@
   requiredn $0 2 $# name value ...
   local _key="$MDB_NODE_NAME"

   unset _ddb_error
   local _q=ddb-update-expr( "SET" $@ )
   aws:ddb-update-item  -table "$MDB_NAME" -key ddb-key( "$_key" )  \
      -update "$_q" -attr-name-expr $_nexpr -attr-value-expr $_vexpr   (error)>{_ddb_error} ||
       ddb-trace $0 $_false
    ##   aws:ddb-update-item -table DBCluster ddb-key( item1 x ) ddb-update-expr( x 2 )
}

# create a new item recorc
# - Q: This does NOT cause an error if the record already exists - should this be
# a conditional put ?
# mdb-create-item name value ...
function mdb-create-item()
{
   trace $0 $@
   requiredn $0 2 $# $@ key value ...
   mdb-update $@
 }


# [OK]
# Delete the entire item/row
function mdb-delete-item()
{
   local ITEM="$MDB_NODE_NAME"
   aws:ddb-delete-item -table "$MDB_NAME"  -key ddb-key( "$ITEM" )  (error)>{_ddb_error} ||
     ddb-trace $0 {$_false}
}


# [OK]
function mdb-delete-attributes()
{
   local ITEM="$MDB_NODE_NAME"
   unset _nexpr
   local _u
   local _names=ddb-expr-names( $# )
   for _n ; do
     local _ne=${_names[1]}
     shift _names;
     _nexpr=aws:ddb-attr-name-exprs(  $_nexpr  aws:ddb-attr-name-expr( "$_ne" "$_n" ) )
     _u+=( "$_ne" )
  done
  local _r=str:join(  "," $_u)
  local _q="REMOVE $_r"
  unset _ddb_error
  aws:ddb-update-item  -table "$MDB_NAME" -key ddb-key( "$ITEM" )  \
      -update "$_q" -attr-name-expr $_nexpr (error)>{_ddb_error}  ||
     ddb-trace $0 $_false

}

#
# Update the instance state by updating the time and state with a conditional
# update only if the time hasnt changed
function mdb-update-instance-state()
{
    trace $0 $@

   if [ $# -gt 1 ] ; then
###
###  Appears to be dead code
###

     # Keep quiet this is run every minute  from cron
     message "Updating instance state to running for $1 to $2"

     local _a=mdb-get-attributes-from-instance( $1 )
     local _tm=mdb-get-attribute( $_a "instance-time" )
     local _n=mdb-get-attribute( $_a node)
     local _err;
     unset _ddb_error
     local ITEM=$MDB_NODE_NAME
     local _q=ddb-update-expr( "SET" instance-state "$2" )

     # IF instance-time = $_tm
     # create the condition name/value mappings
     local _condition="#itime = :ivalue"
     _nexpr=aws:ddb-attr-name-exprs( $_nexpr  aws:ddb-attr-name-expr( "#itime" "instance-time" ) )
     _vexpr=aws:ddb-attr-value-exprs( $_vexpr  aws:ddb-attr-value-expr( ":ivalue" $_tm ) )

      aws:ddb-update-item  -table "$MDB_NAME" -key ddb-key( "$ITEM" )  \
        -condition "$_condition" -update "$_q" \
        -attr-name-expr $_nexpr -attr-value-expr $_vexpr \
          >(_out) (error)>{_ddb_error} ||
             # error due to invalid condition or actual error
             return ddb-handle-error( $? {$_out} ${_ddb_err} )
   else
###
###  Live code with 0 args
###
    # message "Updating instance state to running for $MARKLOGIC_INSTANCE"
     mdb-update state-instance $MARKLOGIC_INSTANCE instance-state running instance-time <[ fn:current-dateTime() ]> ||
       message "Failed to update instance state"
  fi
}

# [OK]
function mdb-get-all-items()
{
   trace $0
   return ddb-scan( )
}

# [OK]
# returns <item>* for all nodes
function mdb-get-attributes-for-node()
{
   required $0 node $@
   local _ITEM="$1"
   local _a
   aws:ddb-get-item -c -table "$MDB_NAME"  -key ddb-key("$_ITEM" ) \
         >{_a} (error)>{_ddb_error} ||
         return ddb-trace( $0 {$_empty} $_a "$*")
   local _r=ddb-items-to-mdb( <[ $_a//item ]> )
   return $_r
}



# [ OK ]
# Query if a MDB 'domain' (SDB Domain or DDB Table) exist
function mdb-domain-exists() {
      ddb-table-exists "$@"
}

function mdb-get-master-hostname()
{
    local _filter="master=:one"
    local _vexpr=aws:ddb-attr-value-expr( ":one" 1 )
    local result
    unset _ddb_error
     aws:ddb-scan   -table "$MDB_NAME"  -projection-expression "host"   \
      -filter $_filter -attr-value-expr  $_vexpr >{result} (error)>{_ddb_error} ||
            return ddb-trace( $0 $_empty $@ )
   return mdb-get-attribute( ddb-items-to-mdb( $result )  "host" )
}


function mdb-get-attributes-from-instance()
{
   trace $0 
   required $0 instance $@
   local _i=$1
   local _filter="#instance=:instance"
   local _vexpr=aws:ddb-attr-value-expr( ":instance"  "$1")
   local _nexpr=aws:ddb-attr-name-expr( "#instance" "instance" )
   local result
   unset _ddb_error
   aws:ddb-scan   -table "$MDB_NAME"  -filter $_filter -attr-value-expr $_vexpr  \
     -attr-name-expr $_nexpr  >{result} (errorcd )>{_ddb_error} ||
            return ddb-trace( $0 $_empty $@ )
   return ddb-items-to-mdb( $result ) 
}



function mdb-get-master-instance()
{
    trace $0 $@
    local _filter="master=:one"
    local _vexpr=aws:ddb-attr-value-expr( ":one" 1 )
    local result
    unset _ddb_error
     aws:ddb-scan   -table "$MDB_NAME"  -projection-expression "instance"   \
      -filter $_filter -attr-value-expr $_vexpr  >{result} (error)>{_ddb_error} ||
            return ddb-trace( $0 $_empty $@ )
   return mdb-get-attribute( ddb-items-to-mdb( $result )  "instance" )
}

function mdb-get-master-state()
{

    local _filter="master=:one"
    local _vexpr=aws:ddb-attr-value-expr( ":one" 1 )
    local _nexpr=aws:ddb-attr-name-expr( "#state" "state" )
    local result
    unset _ddb_error
     aws:ddb-scan   -table "$MDB_NAME"  -projection-expression "#state"   \
      -filter $_filter -attr-value-expr $_vexpr -attr-name-expr $_nexpr   \
         >{result} (error)>{_ddb_error} ||
            return ddb-trace( $0 $_empty $@ )
   return mdb-get-attribute( ddb-items-to-mdb( $result )  "state" )
}


function mdb-get-master-nodename()
{

    local _filter="master=:one"
    local _vexpr=aws:ddb-attr-value-expr( ":one" 1 )
    local _nexpr=aws:ddb-attr-name-expr( "#node" "node" )
    local result
    unset _ddb_error
     aws:ddb-scan   -table "$MDB_NAME"  -projection-expression "#node"   \
      -filter $_filter -attr-value-expr $_vexpr -attr-name-expr $_nexpr   \
         >{result} (error)>{_ddb_error} ||
            return ddb-trace( $0 $_empty $@ )
   return mdb-get-attribute( ddb-items-to-mdb( $result )  "node" )

}


# Return host,instance,master attributes
# [ OK ]
function mdb-get-all-hosts() {
    local result
     aws:ddb-scan -table "$MDB_NAME" projection-expression \
        "node,host,instance,master"  >{result} (error)>{_ddb_error}  ||
           return ddb-trace( $0 {$_empty} $@ )
   return  ddb-items-to-mdb( $result )

}

#bug:55079
#get a nodename for a particular host
function mdb-get-nodename-with-hostname()
{
    local _hname=$1 
    local _filter="host=:hname"
    local _vexpr=aws:ddb-attr-value-expr( ":hname" "$_hname" )
    local _nexpr=aws:ddb-attr-name-expr( "#node" "node" )
    local result
    unset _ddb_error
     aws:ddb-scan   -table "$MDB_NAME"  -projection-expression "#node"   \
      -filter $_filter -attr-value-expr $_vexpr -attr-name-expr $_nexpr   \
         >{result} (error)>{_ddb_error} ||
            return ddb-trace( $0 $_empty $@ )
    return mdb-get-attribute( ddb-items-to-mdb( $result )  "node" )

}

#bug:55079
#GET INDEX FOR A PARTICULAR HOST
function mdb-get-index-with-hostname()
{
    local _hname=$1 
    local _filter="host=:hname"
    local _vexpr=aws:ddb-attr-value-expr( ":hname" "$_hname" )
    local _nexpr=aws:ddb-attr-name-expr( "#index" "index" )
    local result
    unset _ddb_error
     aws:ddb-scan   -table "$MDB_NAME"  -projection-expression "#index"   \
      -filter $_filter -attr-value-expr $_vexpr -attr-name-expr $_nexpr   \
         >{result} (error)>{_ddb_error} ||
            return ddb-trace( $0 $_empty $@ )
    return mdb-get-attribute( ddb-items-to-mdb( $result )  "index" )

}

#
function mdb-get-index-in-zone()
{
   required $0 zone $@
   local _z=$1 
   shift ;
   local result
   local _filter="#zone=:zone"
   local _vexpr=aws:ddb-attr-value-expr( ":zone" "$_z" )
   local _nexpr=aws:ddb-attr-name-exprs( \
          aws:ddb-attr-name-expr( "#zone" "zone" ) \
          aws:ddb-attr-name-expr( "#index" "index" ) )
   unset _ddb_error
   aws:ddb-scan   -table "$MDB_NAME"  -projection-expression "#index" \
         -filter $_filter -attr-value-expr $_vexpr -attr-name-expr $_nexpr  \
          >{result} (error)>{_ddb_error}  ||
      return ddb-trace( $0 {$_empty} $@ )

   local _items=ddb-items-to-mdb( $result )
    return <[ ($_items/index/xs:integer(.)) ]>
}



# mdb-add-device-entry ebs-vol  ebs dev volid mount
function mdb-add-device-entry()
{
  mdb-validate-device-entry $@
  local _val=$?
  if [ ${_val} -eq 0 ] ; then
    local _d="$1,$2,$3,$4"
    local _ss=<[ <s type="SS">{$_d}</s> ]>
    # use a SS
    unset _ddb_error
    local ITEM=$MDB_NODE_NAME
    local _q="ADD  device :l"
    local _vexpr=aws:ddb-attr-value-expr( ":l"  $_ss )

    unset _ddb_error
    aws:ddb-update-item  -table "$MDB_NAME" -key ddb-key( "$ITEM" )  \
      -update "$_q"  -attr-value-expr $_vexpr (error)>{_ddb_error} ||
         ddb-trace $0 $_false $@
  else
      trace-return $0 $_false "Device entry already exists in MDB"
  fi
}

#
#### NOTE
#  the following structured type is a better representation
#  but I found no way to append to an empty list without a round trip
# using a String Set (SS) is similar to how SDB is done
######

# mdb-add-device-entry ebs-vol  ebs dev volid mount
function mdb-add-device-entry2()
{
  requiredn $0 4 $# ebs dev volid mount
  # use a structured entry "M"
  local _d=<[
       <device type="M" >
          <ebs>{$_1}</ebs>
          <dev>{$_2}</dev>
          <volid>{$_3}</volid>
          <mount>{$_4}</mount>
       </device>
     ]>
   echo setting $_d
   unset _ddb_error
   local ITEM=$MDB_NODE_NAME
   local _q="SET #dev = :l"
   local _vexpr=aws:ddb-attr-value-expr( ":l" $_d )
   local _nexpr=aws:ddb-attr-name-expr( "#dev" "$2" )

   aws:ddb-update-item  -table "$MDB_NAME" -key ddb-key( "$ITEM" )  \
      -update "$_q" -attr-name-expr $_nexpr -attr-value-expr $_vexpr (error)>{_ddb_error} ||
      ddb-trace $0 $_false $@
}

# Returns the <item> recored for our node
function mdb-test()
{
   local _ITEM="$MDB_NODE_NAME"
   local _a
   unset _ddb_error
   aws:ddb-get-item -c -table "$MDB_NAME"  -key ddb-key("$_ITEM" ) \
         >{_a} (error)>{_ddb_error} ||
         ddb-trace $0 {$_a} ${_ddb_error} $@
   return $_a
}


# [ OK]
#  mdb-update-if-equals Key attribute expected-value attr value [attr value ..]
#  Update only if attribute ($2) exists and has value ($3)
function mdb-update-if-equals()
{
  [ $# -gt 3 ] || error "mdb-update-if-equals: expected arguments key attribute expected-value attr value [attr value ..]"
  local _N="$1"
  local _aname="$2"
  local _avalue="$3"
  shift 3

   unset _ddb_error
   local _condition="attribute_exists(#aname) AND #aname = :avalue"
   local _q=ddb-update-expr( "SET" $@ )
   _nexpr=aws:ddb-attr-name-exprs( $_nexpr  aws:ddb-attr-name-expr( "#aname" "$_aname" ) )
   _vexpr=aws:ddb-attr-value-exprs( $_vexpr  aws:ddb-attr-value-expr( ":avalue" $_avalue ) )

   aws:ddb-update-item  -table "$MDB_NAME" -key ddb-key( "$_N" )  \
      -update "$_q" -condition "$_condition" -attr-name-expr $_nexpr \
      -attr-value-expr $_vexpr   (error)>{_ddb_error} ||
     ddb-condition-error $0 $_false $@
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

  local _err
  #####################################
  # try to put only if slot doesnt exist
  # insert record (key ==node) if node does not exist
  #  OR
  # update record if instance exists and = $INSTANCE
  ####
  # Note on DDB PutItem - you cannot specify any primary key field as one of the
  # attributes, you get a paramater violation failure. Reguardless of a new or updated node.
  # so omit the 'node' attribute and only use it in the key value.
  ###
  local _dt=<[ fn:current-dateTime() ]>
  local _attrs=(  )


   local _condition="attribute_not_exists(#n) OR  #i = :i"
      ## The node is in the key so dont include it in the attributes
   local _atts=ddb-attrs-name-value( create-date $_dt  \
       instance "$_inst" zone "$_zone"  $@ )

   local _nexpr=aws:ddb-attr-name-exprs(  aws:ddb-attr-name-expr( "#n" "node") \
        aws:ddb-attr-name-expr( "#i" "instance") )
   local _vexpr=aws:ddb-attr-value-expr( ":i" $_inst )
   unset _ddb_error
   ## The node is in the key so dont include it in the attributes
   aws:ddb-put-item   -table "$MDB_NAME" -key ddb-key( "$_N" )  \
          -condition "$_condition" -attr-name-expr $_nexpr \
          -attr-value-expr $_vexpr  $_atts  (error)>{_ddb_error} ||
      ddb-condition-error $0 $_false $@
}



