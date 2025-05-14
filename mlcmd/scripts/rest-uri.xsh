# rest-uri  [ -host host ] [-port port ] [ -scheme scheme] [-uri uri ] [ -path path ] 
# Copyright (c) 2020 MarkLogic Corporation 
. init

_opts=$<(xgetopts -o "host:,port:,scheme:,uri:,path:" -a -noargs --  "$@")
shift $?

if [ $# -gt 0 ] ; then
   QUERY=$(xurlencode -q  "$@")
fi


MLURI=getopt( $_opts uri $MLURI )
if [ -n "$MLURI" ] ; then
  MLPORT=$(xuri -port $MLURI)
  MLSCHEME=$(xuri -scheme $MLURI)
  MLHOST=$(xuri -host $MLURI)
  MLPATH=$(xuri -path $MLURI)
fi




MLPORT=getopt( $_opts port $MLPORT )
MLPATH=getopt( $_opts path $MLPATH /)
MLHOST=getopt( $_opts host $MLHOST localhost) 
MLSCHEME=getopt( $_opts scheme $MLSCHEME http) 


xuri -Q "$MLSCHEME" "" "$MLHOST" "$MLPORT" "$MLPATH" "$QUERY" ""
