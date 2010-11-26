<?php

require("d0_blind_id.inc");
$d0_blind_id_keygen = "/opt/d0_blind_id/bin/crypto-keygen-standalone";

// read raw POST data
list($status, $idfp) = d0_blind_id_verify();
$version = $_GET["version"];
$postdata = $_POST["foo"];

// log access
$ip = $_SERVER["REMOTE_ADDR"];
if($idfp)
	syslog(LOG_NOTICE, "update notification was called by $idfp ($status, $postdata) at $ip for version $version");
else if($version)
	syslog(LOG_NOTICE, "update notification was called by an unknown user at $ip for version $version");
else
	syslog(LOG_NOTICE, "update notification was called by an unknown user at $ip");

header("Content-type: text/plain");
echo "0\n";
echo "file:///dev/null\n";

?>
