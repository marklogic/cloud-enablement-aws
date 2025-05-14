#!/bin/sh mlcmd
# Copyright (c) 2020 MarkLogic Corporation 
. init
# ( <item> .. 
nodes=mdb-get-all-items()

good=<[
  for $node in $nodes
  let
      $hostid := $node/hostid/normalize-space(.) ,
      $newhost := $node/newhost/normalize-space(.) , 
      $host := $node/host/normalize-space(.) , 
      $is   := $node/instance-state/normalize-space(.) ,
      $isd  := xs:dateTime( $node/instance-time  ),
      $twomin := fn:current-dateTime() - xs:dayTimeDuration("PT2M")
   where ( $is eq "running" and $isd gt $twomin )
      return if( string-length($hostid) gt 0 ) then concat( $hostid , "," , ($newhost,$host )[.][1]  ) else ()
]>
xecho -n $good
