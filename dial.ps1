#!pwsh -NoLogo

param (
    [Parameter()]
    [String] $phoneNumberToDial,
    
    [Parameter()]
    [Switch]
    [Boolean] $registerHandlers
)

#specify the com port on which to talk to the modem:
$nameOfSerialPort='COM5'

if($registerHandlers){
    # thanks to https://itectec.com/superuser/cant-change-tel-protocol-handler-in-windows-10/
    # register this script as the default handler for "tel:" and "callto:" urls.  
    # I do not entirely understand how the registry keys determine the default handler, so I may be doing some  unnecessary things below.
    
    Write-Host "registering $PSCommandPath as the protocol handler for tel: and callto: urls."
    
    # $openCommand = "env `"$PSCommandPath`" -phoneNumberToDial `"%1`""
    $openCommand = "pwsh `"$PSCommandPath`" -phoneNumberToDial `"%1`""
    
    $nameOfThisApplication="neildial"
    
    $pathOfRegistryKeyForThisApplication = Join-Path "registry::HKEY_CURRENT_USER\SOFTWARE\" $nameOfThisApplication
    $pathOfCapabilitiesKey=(Join-Path $pathOfRegistryKeyForThisApplication "Capabilities")
    $pathOfUrlAssociationsKey=(Join-Path $pathOfCapabilitiesKey "URLAssociations")
    
    #caution: new-item -force will overwrite an existing item if it exists.
    $registryKeyForThisApplication = ((Get-Item -ErrorAction Ignore -Path $pathOfRegistryKeyForThisApplication) ?? (New-Item -Force -Path $pathOfRegistryKeyForThisApplication))
    $capabilitiesKey = ((Get-Item -ErrorAction Ignore -Path $pathOfCapabilitiesKey) ?? (New-Item -Force -Path $pathOfCapabilitiesKey))
    $urlAssociationsKey = ((Get-Item -ErrorAction Ignore -Path $pathOfUrlAssociationsKey) ?? (New-Item -Force -Path $pathOfUrlAssociationsKey))
    $registeredApplicationsKey = (Get-Item -Path "registry::HKEY_CURRENT_USER\SOFTWARE\RegisteredApplications")
    
    $capabilitiesKey | Set-ItemProperty -Name "ApplicationDescription" -Value $nameOfThisApplication
    $capabilitiesKey | Set-ItemProperty -Name "ApplicationName" -Value $nameOfThisApplication
    $registeredApplicationsKey | Set-ItemProperty -Name $nameOfThisApplication -Value "Software\$nameOfThisApplication\Capabilities"


    
    foreach($protocolName in @("callto","tel")){
        
        $pathOfUserChoiceKey = "registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\$protocolName\UserChoice"
        
        $preferredProgId="$nameOfThisApplication.$protocolName"
        $progIds = @($preferredProgId, $protocolName)
        
        $userChoiceKey = ( (Get-Item -ErrorAction Ignore -Path $pathOfUserChoiceKey) ?? (New-Item -Force -Path $pathOfUserChoiceKey))
        $userChoiceKey | Set-ItemProperty -Name "ProgId" -Value $preferredProgId
        
        foreach($progId in $progIds){
            $pathOfRegistryKeyForClass = Join-Path "registry::HKEY_CURRENT_USER\SOFTWARE\Classes" $progId
            $pathOfCommandKey = (Join-Path $pathOfRegistryKeyForClass "Shell\Open\Command")
            $pathOfApplicationKey = (Join-Path $pathOfRegistryKeyForClass "Application")
            
            $registryKeyForClass = ((Get-Item -ErrorAction Ignore -Path $pathOfRegistryKeyForClass) ?? (New-Item -Force -Path $pathOfRegistryKeyForClass))
            $applicationKey = ((Get-Item -ErrorAction Ignore -Path $pathOfApplicationKey) ?? (New-Item -Force -Path $pathOfApplicationKey))
            $commandKey = ((Get-Item -ErrorAction Ignore -Path $pathOfCommandKey) ?? (New-Item -Force -Path $pathOfCommandKey))
            

            $registryKeyForClass | Set-ItemProperty -Name '(Default)' -Value "URL:$protocolName"
            $registryKeyForClass | Set-ItemProperty -Name "URL Protocol" -Value ""
            $commandKey | Set-ItemProperty -Name '(Default)' -Value $openCommand
            $applicationKey | Set-ItemProperty -Name 'ApplicationName' -Value $nameOfThisApplication
            
        }
        
        $urlAssociationsKey | Set-ItemProperty -Name $protocolName -Value $preferredProgId
    }
    exit 0
} else {
    Write-Host "proceeding to dial.  "
}
# Write-Host "regsiterHAndlers is $registerHandlers"
#discard non-digits

$sanitizedPhoneNumberToDial=$phoneNumberToDial -replace "[^0123456789#\*,]",""

Write-Output ("phoneNumberToDial: $phoneNumberToDial")
Write-Output ("sanitizedPhoneNumberToDial: $sanitizedPhoneNumberToDial")

$port= new-Object System.IO.Ports.SerialPort $nameOfSerialPort, 9600,([System.IO.Ports.Parity] 'None' ),8,([System.IO.Ports.StopBits] 'One' )
$port.Handshake = ( [System.IO.Ports.Handshake] 'RequestToSend')
$port.DtrEnable=$true
$port.Open()
$port.ReadExisting() | Out-Null
$port.DtrEnable=$true

$commands = @(
    # turn on echo (mostly for debugging)
    "E1"

    #disable dial tone detection
    "X0"

    #tell the modem to ignore dtr (I suspect that the serial port's dtr line
    #tends to go low when we disconnect.  If the modem were attending to dtr,
    #the modem's default behavior is to hang up the call when dtr goes low.  we
    #want the modem to stay off hook (and we will rely on the lack of carrier
    #detection to cause the modem to decide to hang up of its own accord.
    "&D0"

    #wait-time for carrier after dial before hanging up (Seconds).
    "S7=3" 

    # specify the duration of the pause, in seconds, that the modem will do while
    # dialing when it encounters a comma (",") in the dialing string.
    "S8=2"

    "DT$($sanitizedPhoneNumberToDial)"


    ## see section 3.2.3 of the Conexant "Commands for Host Precessed and Host-Controlled Modems Reference Manual" (Conexant document number 100498D, April 5, 2001)
    ## for allowable characters in the dialing string:
    ##
    ##  Syntax
    ##  D<modifier>
    ##  Defined Values
    ##  <modifier> The valid dial string parameters (modifiers) are described below.
    ##  Punctuation characters may be used for clarity, with parentheses,
    ##  hyphen, and spaces ignored.
    ##  0-9 DTMF digits 0 to 9.
    ##  A-D DTMF digits A, B, C, and D. Some countries may prohibit sending
    ##  of these digits during dialing.
    ##  L Re-dial last number: the modem will re-dial the last valid
    ##  telephone number. The L must be immediately
    ##  
    ##  P Select pulse dialing: pulse dial the numbers that follow until a "T"
    ##  is encountered. Affects current and subsequent dialing. Some
    ##  countries prevent changing dialing modes after the first digit is
    ##  dialed.
    ##  T Select tone dialing: tone dial the numbers that follow until a "P" is
    ##  encountered. Affects current and subsequent dialing. Some
    ##  countries prevent changing dialing modes after the first digit is
    ##  dialed.
    ##  W Wait for dial tone: the modem will wait for dial tone before dialing
    ##  the digits following "W". If dial tone is not detected within the
    ##  time specified by S7 or S6, the modem will abort the rest of the
    ##  sequence, return on-hook, and generate an error message.
    ##  * The 'star' digit (tone dialing only).
    ##  # The 'gate' digit (tone dialing only).
    ##  +
    ##  
    ##  ! Flash: the modem will go on-hook for a time defined by the value
    ##  of S29. Country requirements may limit the time imposed.
    ##  @ Wait for silence: the modem will wait for at least 5 seconds of
    ##  silence in the call progress frequency band before continuing with
    ##  the next dial string parameter. If the modem does not detect these 5
    ##  seconds of silence before the expiration of the call abort timer (S7),
    ##  the modem will terminate the call attempt with a NO ANSWER
    ##  message. If busy detection is enabled, the modem may terminate
    ##  the call with the BUSY result code. If answer tone arrives during
    ##  execution of this parameter, the modem will handshake.
    ##  $ Wait for credit card dialing tone before continuing with the dial
    ##  string. If the tone is not detected within the time specified by S7 or
    ##  S6, the modem will abort the rest of the sequence, return on-hook,
    ##  and generate an error message.
    ##  & Wait for credit card dialing tone before continuing with the dial
    ##  string. If the tone is not detected within the time specified by S7 or
    ##  S6, the modem will abort the rest of the sequence, return on-hook,
    ##  and generate an error message.
    ##  , Dial pause: the modem will pause for a time specified by S8 before
    ##  dialing the digits following ",".
    ##  ; Return to command state. Added to the end of a dial string. This
    ##  causes the modem to return to the command state after it processes
    ##  the portion of the dial string preceding the ";". This allows the user
    ##  to issue additional commands while remaining off-hook. The
    ##  additional commands may be placed in the original command line
    ##  following the ";" and/or may be entered on subsequent command
    ##  lines. The modem will enter call progress only after an additional
    ##  dial command is issued without the ";" terminator. Use "H" to
    ##  abort the dial in progress, and go back on-hook.
    ##  ^ Toggles calling tone enable/disable: applicable to current dial
    ##  attempt only.
    ##  ( ) Ignored: may be used to format the dial string.
    ##  - Ignored: may be used to format the dial string.
    ##  <space> Ignored: may be used to format the dial string.

)
$port.Write("`r")
foreach($command in $commands){
    $port.Write("AT" + $command + "`r")
}

$port.ReadExisting()
$port.Close()







#====================================================
#Speaker on until remote carrier detected:
# $port.Write("ATZ0`r") 
# Start-Sleep 10
# $port.Write("ATE1`r") 
# $port.Write("ATV1`r") 
# $port.Write("ATI1`r") 
# $port.Write("ATI3`r") 
# $port.Write("ATX0`r") 
# $port.Write("ATDT`r")
# $port.Write("ATH1`r`n") 
# Start-Sleep 1
# $port.Close()
# Start-Sleep 1
# $port.Open()
# 

#put the line on hook:
# $port.Write("ATH0`r")

#disable dial-tone detection:
# $port.Write("ATX0`r")

#take the line off hook:
# $port.Write("ATH1`r")

#dial the number:
# $port.Write("ATD4252186726")
# Start-Sleep 1
# $port.Write("`r")
#hang up:
# $port.Write("ATH0`r")

# $command = "D4252186726H0`r"

# $byteArray = ([system.Text.Encoding]::ASCII).GetBytes($command)
# $byteArray
# $port.Write($command)
# $command = "`rATDT4252186726&V`r"
# $command = "`rAT&V`r"
# $commands = @(
    # "E1", #turn on echo (mostly for debugging
    # "X0", #disable dial tone detection
    # "&D0", #tell the modem to ignore dtr (I suspect that the serial port's dtr line tends to go low when we disconnect.  If the modem were attending to dtr, the modem's default behavior is to hang up the call when dtr goes low.  we want the modem to stay off hook (and we will rely on the lack of carrier detection to cause the modem to decide to hang up of its own accord.
    # "S7=3", #wait-time for carrier after dial before hanging up (Seconds).
    # ("DT" + $sanitizedPhoneNumberToDial)
# )
# $port.Write("`r")
# foreach($command in $commands){
    # $port.Write("AT" + $command + "`r")
# }


# # while ($true) {
    # # while(! $port.BytesToRead){
        # # Start-Sleep 0.5
    # # }
    # # $port.ReadExisting()
# # }

# # # $port.Write("ATH0`r`n") 
# # $port.ReadExisting()
# # Start-Sleep 10
# # $port.Write("ATH0`r`n") 
# $port.ReadExisting()
# $port.Close()



# [System.IO.Ports.SerialPort]::getportnames()












# $uart = new-Object System.IO.Ports.SerialPort;
# $uart.PortName = "COM20";
# $uart.BaudRate = 115200;
# $uart.DataBits = 8;
# $uart.Parity = System.IO.Ports.Parity.None;
# $uart.StopBits = 1;
# $uart.Handshake = System.IO.Ports.Handshake.None;

# $uart = new-Object System.IO.Ports.SerialPort COM3,115200,None,8,one
# #Write-Host ("AT" + "X0"  + ([char]10) + ([char]10))
# $uart.Open(); 
# #$uart.WriteLine("AT" + "DT" + "4252186726")
# $uart.Write("A")
# Start-Sleep -Milliseconds 100
# $uart.Write("T")
# Start-Sleep -Milliseconds 100
# $uart.Write("`n")
# Start-Sleep -Milliseconds 100
# Write-Host ($uart.ReadLine() + ([char]10))
# Start-Sleep -Milliseconds 2000
# $uart.Close();


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