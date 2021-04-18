<?php

$argument = 
	implode(
		" ",
		array_slice($argv,1) // we want all but the first element of $argv, which is te name of the script itself.
		);

		
$digitString = preg_replace("/\D/","",$argument);

$digitString = "4252186726"; //debugging

exec("mode COM3: BAUD=115200 PARITY=N data=8 stop=1 XON=off TO=on", $output, $exitCode);

//echo "\$output: " . print_r($output, true) . "\n";
echo "\$exitCode: " . $exitCode . "\n";


// $modemStream = fopen("COM3",'w');
// echo "is_resource(\$modemStream): " . is_resource($modemStream) . "\n";
// fwrite($modemStream, "ATDT" . $digitString . "\n");
// sleep(5);

$commandString = "set /p x=\"4252186726\" <nulset /p x=\"4252186726\" <nul >\\\\.\\COM3";
$commandString = "echo ATDT4252186726 >\\\\.\\COM3";

echo $commandString;
exec($commandString);

sleep(10);



?>