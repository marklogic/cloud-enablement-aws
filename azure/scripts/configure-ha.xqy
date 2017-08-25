xquery=
xquery version "1.0-ml";
declare namespace host = "http://marklogic.com/xdmp/status/host";
import module namespace admin = "http://marklogic.com/xdmp/admin"
		  at "/MarkLogic/admin.xqy";
let $replica-postfix := "-Replica"
let $config := admin:get-configuration()
let $bootstrap-host := xdmp:host()
(: randomly pick one host for replica forests :)
let $replica-host := (xdmp:host-status(xdmp:hosts())/host:host-id/text()[. ne $bootstrap-host])[1]
let $db-names := xdmp:database-name(xdmp:databases())
let $forest-create-replica :=
(
  for $db in $db-names
  if (not(admin:forest-exists($config,fn:concat($db,$replica-postfix))))
  then
  	let $new-config := admin:forest-create($config,fn:concat($db,"-Replica"),$replica-host,())
  	let $master-forest-id := admin:forest-get-id($new-config,$db)
  	let $replica-forest-id := admin:forest-get-id($new-config,fn:concat($db,$replica-postfix))
  	let $new-config := admin:forest-add-replica($new-config,$master-forest-id,$replica-forest-id)
  	return xdmp:set($config,$new-config)
  else ()
)
let $save-config := admin:save-configuration($config)
return "Successfully create replica forests"