<?php

// you may want to override these after including this file
$d0_blind_id_keygen = "crypto-keygen-standalone";
$d0_blind_id_d0pk = "key_0.d0pk";

// usage:
//   list($status, $idfp) = get_d0_blind_id();
// return values:
//   null, null = signature failed
//   "", 0      = not signed
//   idfp, 0    = signed, ID was not signed by CA
//   idfp, 1    = signed, ID was signed by CA
function d0_blind_id_verify()
{
	global $d0_blind_id_keygen;
	global $d0_blind_id_d0pk;

	if($_SERVER["REQUEST_METHOD"] == "POST")
		$data = file_get_contents("php://input") . "\0" . $_SERVER["QUERY_STRING"];
	else
		$data = $_SERVER["QUERY_STRING"];
	$sig = $_SERVER["HTTP_X_D0_BLIND_ID_DETACHED_SIGNATURE"];
	if($sig)
	{
		// check signature
		putenv("KEYGEN=$d0_blind_id_keygen");
		$checker = proc_open(
				"\"\$KEYGEN\" -p /dev/fd/3 -d /dev/fd/4 -s /dev/fd/5",
				array(
					1 => array("pipe", "w"),
					3 => array("file", $d0_blind_id_d0pk, "r"),
					4 => array("pipe", "r"),
					5 => array("pipe", "r")
				     ),
				$pipes,
				null,
				null,
				array("binary_pipes")
				);
		if(!$checker)
			die("Cannot start process");
		$outfh = $pipes[1];
		$buffers = array(
				4 => $data,
				5 => base64_decode($sig)
				);
		$rpipes = array(
				4 => $pipes[4],
				5 => $pipes[5]
			       );
		foreach($rpipes as $p)
			stream_set_blocking($p, 0);
		while(!empty($rpipes))
		{
			$readers = null;
			$writers = $rpipes;
			$errorers = $rpipes;
			$n = stream_select($readers, $writers, $errorers, 1, 0);
			if($n == 0)
				break;
			$n = 0;
			foreach($errorers as $e)
			{
				$i = array_search($e, $rpipes);
				if($i === false)
					continue;
				fclose($pipes[$i]);
				unset($buffers[$i]);
				unset($rpipes[$i]);
				++$n;
			}
			foreach($writers as $w)
			{
				$i = array_search($w, $rpipes);
				if($i === false)
					continue;
				$written = fwrite($w, $buffers[$i], strlen($buffers[$i]));
				if($written)
					$buffers[$i] = substr($buffers[$i], $written);
				if($buffers[$i] == "")
				{
					fclose($pipes[$i]);
					unset($buffers[$i]);
					unset($rpipes[$i]);
				}
				++$n;
			}
			if(!$n)
				break;
		}
		if($buffers)
			die("could not write data to process");
		$status = stream_get_line($outfh, 8192, "\n");
		$idfp = stream_get_line($outfh, 8192, "\n");
		$ret = proc_close($checker);
		if($ret != 0)
			return array(null, null);
		return array($idfp, $status);
	}
	else
		return array("", 0);
}
?>
