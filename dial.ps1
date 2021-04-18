# $uart = new-Object System.IO.Ports.SerialPort;
# $uart.PortName = "COM20";
# $uart.BaudRate = 115200;
# $uart.DataBits = 8;
# $uart.Parity = System.IO.Ports.Parity.None;
# $uart.StopBits = 1;
# $uart.Handshake = System.IO.Ports.Handshake.None;

$uart = new-Object System.IO.Ports.SerialPort COM3,115200,None,8,one
#Write-Host ("AT" + "X0"  + ([char]10) + ([char]10))
$uart.Open(); 
#$uart.WriteLine("AT" + "DT" + "4252186726")
$uart.Write("A")
Start-Sleep -Milliseconds 100
$uart.Write("T")
Start-Sleep -Milliseconds 100
$uart.Write("`n")
Start-Sleep -Milliseconds 100
Write-Host ($uart.ReadLine() + ([char]10))
Start-Sleep -Milliseconds 2000
$uart.Close();


# $uart.Write("AT" + "L0" + ([char]10) ); #set speaker loudness to zero
# Start-Sleep -Milliseconds 2000

# $uart.Write("AT" + "M0" + ([char]10)); #alternate command to set speaker loudness to zero.
# Start-Sleep -Milliseconds 2000
# $uart.Write("AT" + "L3" + ([char]10)); #set speaker volume to high
# Start-Sleep -Milliseconds 2000
# $uart.Write("AT" + "M2" + ([char]10)); #turn speaker on
# Start-Sleep -Milliseconds 2000
# $uart.Write("AT" + "X0"  + ([char]10)); #disable dial tone detection (i.e. blindly dial regardless of whether a dial toe exists.)
# Start-Sleep -Milliseconds 2000
# #$uart.Write("AT" + "DT" + "4252186726" + "&" + "H0" + ([char]10))
# $uart.Write("AT" + "DT" + "4252186726" + ([char]10))
# Start-Sleep -Milliseconds 30000

# #$uart.Write("AT" + "H0" + ([char]10)); #hang up

# #$uart.Write(
# #    "AT" + 
# #        "X0"  + "&" +
# #        "DT" + "4252186726" + "&" + 
# #        "H0" + 
# #        ([char]10)
# #)
# #
# #$uart.WriteLine("ATX0&M2&DT4252186726&H0");



# $uart.Close();