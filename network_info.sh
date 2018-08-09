#!/bin/bash
#
# Script to list information about network interfaces on Mac OS X [10.9]
#
# Copyright 2015 Peter Möller
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Version:
VER="1.0"

help() {
  echo
  echo "Usage: $0 [-u]"
  echo
  echo "-u: Update the script"
  echo
  echo "If run by root: datafiles in /Library/cs.lth.se/OpenPorts (Mac) or /usr/share/cs.lth.se/OpenPorts (Linux) are created, but no output."
  echo "If run by any other user: output is displayed based on those datafiles."
  echo
  echo "This script is supposed to be used in conjunction with a launchd-component, se.lth.cs.open_ports,"
  echo "that creates the datafiles in /Library/OpenPorts every two minutes. The use of GeekTool to display the result"
  echo "is also part of the idea behind this script!"
  exit 0
}

# Read the parameters:
while getopts ":hud" opt; do
case $opt in
    u ) fetch_new=t;;
    d ) debug=t;;
 \?|h ) help;;
esac
done


# Find where the script resides (so updates update the correct version) -- without trailing slash
DirName="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# What is the name of the script? (without any PATH)
ScriptName="$(basename $0)"
# Is the file writable?
if [ -w "${DirName}/${ScriptName}" ]; then
  Writable="yes"
else
  Writable="no"
fi
# Who owns the script?
ScriptOwner="$(ls -ls ${DirName}/${ScriptName} | awk '{print $4":"$5}')"


# Check for update
function CheckForUpdate()
{
  NewScriptAvailable=f
  # First, download the script from the server
  /usr/bin/curl -s -f -e "$ScriptName ver:$VER" -o /tmp/"$ScriptName" http://fileadmin.cs.lth.se/cs/Personal/Peter_Moller/scripts/"$ScriptName" 2>/dev/null
  /usr/bin/curl -s -f -e "$ScriptName ver:$VER" -o /tmp/"$ScriptName".sha1 http://fileadmin.cs.lth.se/cs/Personal/Peter_Moller/scripts/"$ScriptName".sha1 2>/dev/null
  ERR=$?
  # Find, and print, errors from curl (we assume both curl's above generate the same errors, if any)
  if [ "$ERR" -ne 0 ] ; then
    # Get the appropriate error message from the curl man-page
    # Start with '       43     Internal error. A function was called with a bad parameter.'
    # end get it down to: ' 43: Internal error.'
    ErrorMessage="$(MANWIDTH=500 man curl | egrep -o "^\ *${ERR}\ \ *[^.]*." | perl -pe 's/[0-9](?=\ )/$&:/;s/  */ /g')"
    echo $ErrorMessage
    echo "The file \"$ScriptName\" could not be fetched from \"http://fileadmin.cs.lth.se/cs/Personal/Peter_Moller/scripts/$ScriptName\""
  fi
  # Compare the checksum of the script with the fetched sha1-sum
  # If they diff, there is a new script available
  if [ "$(openssl sha1 /tmp/"$ScriptName" | awk '{ print $2 }')" = "$(less /tmp/"$ScriptName".sha1)" ]; then
    if [ -n "$(diff /tmp/$ScriptName $DirName/$ScriptName 2> /dev/null)" ] ; then
      NewScriptAvailable=t
    fi
  else
    CheckSumError=t
  fi
}


# Update [and quit]
function UpdateScript()
{
  CheckForUpdate
  if [ "$CheckSumError" = "t" ]; then
    echo "Checksum of the fetched \"$ScriptName\" does NOT check out. Look into this! No update performed!"
    exit 1
  fi
  # If new script available, update
  if [ "$NewScriptAvailable" = "t" ]; then
    # But only if the script is writable!
    if [ "$Writable" = "yes" ]; then
      /bin/rm -f "$DirName"/"$ScriptName" 2> /dev/null
      /bin/mv /tmp/"$ScriptName" "$DirName"/"$ScriptName"
      chmod 755 "$DirName"/"$ScriptName"
      /bin/rm /tmp/"$ScriptName".sha1 2>/dev/null
      echo "A new version of \"$ScriptName\" was installed successfully!"
      echo "Script updated. Exiting"

      # Send a signal that someone has updated the script
      # This is only to give me feedback that someone is actually using this. I will *not* use the data in any way nor give it away or sell it!
      /usr/bin/curl -s -f -e "$ScriptName ver:$VER" -o /dev/null http://fileadmin.cs.lth.se/cs/Personal/Peter_Moller/scripts/updated 2>/dev/null

      exit 0
    else
      echo "Script cannot be updated!"
      echo "It is located in \"${DirName}\" and is owned by \"${ScriptOwner}\""
      echo "You need to sort this out yourself!!"
      echo "Exiting..."
      exit 1
    fi
  else
    echo "You already have the latest version of \"${ScriptName}\"!"
    exit 0
  fi
}


[[ "$fetch_new" = "t" ]] && UpdateScript

# Basic settings:
# PREFIX points to where the data files are stored. 
# DEFAULT_INTERFACE="$(route get www.lu.se | grep interface | awk '{ print $2 }')"
DEFAULT_INTERFACE="$(/usr/sbin/netstat -f inet -rn | grep "^default" | awk '{print $6}')"
MY_IP_ADDRESS="$(ifconfig $DEFAULT_INTERFACE | grep "inet " | awk '{ print $2 }')"
#DOMAIN="`ipconfig getpacket en0 | grep 'domain_name (string)' | awk '{ print $3 }'`"
DOMAIN="$(hostname | cut -d\. -f2-7)"
MTIME60m="-mtime -60m"
MTIME120m="-mtime +120m"
MTIME7d="-mtime -7d"
# NAT has content if we are on a private net (^192.168.|^172.16.|^10.) and empty otherwise
NAT="$(echo $MY_IP_ADDRESS | egrep "^192.168.|^172.16.|^10.")"
# ScriptName is simply the name of the script...
ppp_presented=""

# (Colors can be found at http://en.wikipedia.org/wiki/ANSI_escape_code, http://graphcomp.com/info/specs/ansi_col.html and other sites)
Reset="\e[0m"
ESC="\e["
RES="0"
BoldFace="1"
ItalicFace="3"
UnderlineFace="4"
SlowBlink="5"

BlackBack="40"
RedBack="41"
GreenBack="42"
YellowBack="43"
BlueBack="44"
CyanBack="46"
WhiteBack="47"

BlackFont="30"
RedFont="31"
GreenFont="32"
YellowFont="33"
BlueFont="34"
CyanFont="36"
WhiteFont="37"

# Colors
ActiveTextColor="$GreenFont"
ActiveBackColor="$GreenBack"
InactiveTextColor="$BlackFont"
InactiveBackColor="$WhiteBack"
DisabledTextColor="$WhiteFont"
DisabledBackColor="$WhiteBack"

# Reset all colors
BGColor="$RES"
Face="$RES"
FontColor="$RES"


# If the script is too old, check for update
# 2014-03-10: not included yet
#if [ -z "$(find $DirName/${ScriptName} -type f ${MTIME7d} 2> /dev/null)" ]; then
#  CheckForUpdate
#fi


# ----------------------------------------------------------------------------------------------------
#
# Print warnings

# If we don't have an IP-address ($DEFAULT_INTERFACE = "") warn the user!!
if [ -z "$DEFAULT_INTERFACE" ]; then
 printf "${ESC}${RedFont}mWARNING: No IP-address detected!!!\n\n$Reset"
fi

# Find out if is IPv6 is configured
if [ -z "$(/sbin/ifconfig $DEFAULT_INTERFACE | grep inet6)" ]; then
 IPv6="f"
else
 IPv6="t"
fi

# End print warnings
#
# ----------------------------------------------------------------------------------------------------


# Prepare what is to be presented regarding the IP-address (if we are behind a NAT it should be prented)
#if [ "$(less $EXTERN)" = "$MY_IP_ADDRESS" ]; then
#  IP_ADDRESS_Display="$MY_IP_ADDRESS"
#else
#  IP_ADDRESS_Display="NAT: $MY_IP_ADDRESS / $(less $EXTERN)"
#fi

# Find out which system version we are running
SW_VERS="$(sw_vers -productName) $(sw_vers -productVersion)"
ComputerName="$(networksetup -getcomputername)"

# Find out if it's a server
# First step: does the name fromsw_vers include "server"?
if [ -z "$(echo "$SW_VERS" | grep -i server)" ]; then
  # If not, it may still be a server. Beginning with OS X 10.8 all versions include the command serverinfo:
  serverinfo --software 1>/dev/null
  # Exit code 0 = server; 1 = NOT server
  ServSoft=$?
  if [ $ServSoft -eq 0 ]; then
    # Is it configured?
    serverinfo --configured 1>/dev/null
    ServConfigured=$?
    if [ $ServConfigured -eq 0 ]; then
      SW_VERS="$SW_VERS ($(serverinfo --productname) $(serverinfo --shortversion))"
    else
      SW_VERS="$SW_VERS ($(serverinfo --productname) $(serverinfo --shortversion) - unconfigured)"
    fi
  fi
fi

# Interesting options to networksetup:
# 
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# 
# $ networksetup -listnetworkserviceorder
# An asterisk (*) denotes that a network service is disabled.
# (1) Thunderbolt Ethernet
# (Hardware Port: Thunderbolt Ethernet, Device: en1)
# 
# (2) Wi-Fi
# (Hardware Port: Wi-Fi, Device: en0)
# 
# (3) Bluetooth DUN
# (Hardware Port: Bluetooth DUN, Device: Bluetooth-Modem)

# (*) USB Ethernet
# (Hardware Port: USB-Ethernet, Device: en5)
# 
# (4) Bluetooth PAN
# (Hardware Port: Bluetooth PAN, Device: en2)
# 
# (5) Thunderbolt Bridge
# (Hardware Port: Thunderbolt Bridge, Device: bridge0)
# 
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# 
# $ networksetup -listallhardwareports
# 
# Hardware Port: Bluetooth DUN
# Device: Bluetooth-Modem
# Ethernet Address: N/A
# 
# Hardware Port: Thunderbolt Ethernet
# Device: en1
# Ethernet Address: 40:6c:8f:3d:6b:b3
# 
# Hardware Port: Wi-Fi
# Device: en0
# Ethernet Address: 14:10:9f:ce:fd:95
# 
# Hardware Port: Bluetooth PAN
# Device: en2
# Ethernet Address: N/A
# 
# Hardware Port: Thunderbolt 1
# Device: en3
# Ethernet Address: 32:00:19:a6:f6:20
# 
# Hardware Port: Thunderbolt 2
# Device: en4
# Ethernet Address: 32:00:19:a6:f6:21
# 
# Hardware Port: Thunderbolt Bridge
# Device: bridge0
# Ethernet Address: N/A
# 
# VLAN Configurations
# ===================
# 
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# 
# $ networksetup -getinfo "Ethernet 1"
# DHCP Configuration
# IP address: 130.235.16.211
# Subnet mask: 255.255.254.0
# Router: 130.235.16.1
# Client ID: 
# IPv6: Automatic
# IPv6 IP address: none
# IPv6 Router: none
# Ethernet Address: 00:3e:e1:be:06:59
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
# $ scutil --nc status 'VPN (L2TP) mot CS'
# Connected
# Extended Status <dictionary> {
#   IPv4 : <dictionary> {
#     Addresses : <array> {
#       0 : 130.235.16.35
#     }
#     DestAddresses : <array> {
#       0 : 130.235.16.20
#     }
#     InterfaceName : ppp0
#     NetworkSignature : VPN.RemoteAddress=130.235.16.20
#     Router : 130.235.16.20
#     ServerAddress : 130.235.16.20
#   }
#   PPP : <dictionary> {
#     CommRemoteAddress : 130.235.16.20
#     ConnectTime : 213787
#     IPCPCompressionVJ : 0
#     LCPCompressionACField : 1
#     LCPCompressionPField : 1
#     LCPMRU : 1500
#     LCPMTU : 1280
#     Status : 8
#   }
#   Status : 2
# }
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# 
# $ scutil --nc status "Thunderbolt Ethernet"
# No service
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
# 
# What I am looking for to print:
#
# The usual head + networksetup -getcomputername (gives "Peters MBPr")
# Priority order   Hardware Port          Interface   IPv4-address   Status/Dynamic   Subnet mask     Router        MAC-address         Media Speed
# 1.               Thunderbolt Ethernet   en1         192.168.1.114  DHCP             255.255.255.0   192.168.1.1   40:6c:8f:3d:6b:b3   1000
# 4                22                     9           17             8                17              17            19                  5
# |  |                     |       |                |       |                |                |                  |
# 1.  Thunderbolt Ethernet  en1     192.168.173.208  Static  255.255.255.128  192.168.173.1    XX:XX:XX:XX:XX:XX
# 12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890
#          1         2         3         4         5         6         7         8         9        10        11        12        13        14
FormatStringInterfaces="%-4s%-22s%-17s%-17s%-15s%-17s%-17s%-19s%-5s"



NIfile="/tmp/NetworkInterfaces_$$.txt"
# networksetup -listnetworkserviceorder  | grep -A 1 "^([0-9])\ " | grep "[a-z][0-9])$" | cut -d: -f2,3 | sed -e 's/, Device//g' -e 's/)//g' -e 's/^ //g' > $NSOfile
networksetup -listnetworkserviceorder | egrep "^\([0-9\*]*\)\ " | sed -e 's/^(//g' -e 's/) /:/' > $NIfile
# Example:
# 1:Bluetooth DUN
# 2:Ethernet 1
# 3:Ethernet 2
# 4:Display Ethernet
# 5:Display FireWire
# 6:Wi-Fi
# *:Bluetooth PAN
# 7:Thunderbolt Bridge

# Determine if there is a ppp-connection:
ppp="$(ifconfig | grep "ppp[0-9]" | awk '{print $1}' | cut -d: -f1)"
# Ex: ppp=’ppp0’
# Also get the data
if [ -n "$ppp" ]; then
  # Find the ppp-address:
  ppp_temp="$(ifconfig | grep -A1 $ppp | tail -1 | grep 'inet ' | awk '{print $2}')"
  # Ex: ppp_temp='130.235.252.33'
  ppp_mask="$(ifconfig | grep -A1 $ppp | tail -1 | grep 'inet ' | awk '{print $6}' | cut -c3-)"
  ppp_mask1="$(echo "ibase=16; $(echo $ppp_mask | cut -c1-2 | tr '[:lower:]' '[:upper:]')" | bc)"
  ppp_mask2="$(echo "ibase=16; $(echo $ppp_mask | cut -c3-4 | tr '[:lower:]' '[:upper:]')" | bc)"
  ppp_mask3="$(echo "ibase=16; $(echo $ppp_mask | cut -c5-6 | tr '[:lower:]' '[:upper:]')" | bc)"
  ppp_mask4="$(echo "ibase=16; $(echo $ppp_mask | cut -c7-8 | tr '[:lower:]' '[:upper:]')" | bc)"
  ppp_mask="${ppp_mask1}.${ppp_mask2}.${ppp_mask3}.${ppp_mask4}"
fi

# Print the head

# First, print if there is an update for the script available
printf "$UpdateMessage"
printf "${ESC}${BlackBack};${WhiteFont}mHostname:${ESC}${WhiteBack};${BlackFont}m $(hostname) ${Reset}   ${ESC}${BlackBack};${WhiteFont}mComputer Name:${ESC}${WhiteBack};${BlackFont}m ${ComputerName} ${Reset}   ${ESC}${BlackBack};${WhiteFont}mRunning:${ESC}${WhiteBack};${BlackFont}m $SW_VERS ${Reset}   ${ESC}${BlackBack};${WhiteFont}mDate & time:${ESC}${WhiteBack};${BlackFont}m $(date +%F", "%R) ${Reset}\n"
echo
#printf "${ESC}${BoldFace}mInformation about network interfaces.${Reset}\n${ESC}${ItalicFace}mExplanation: ${ESC}${ActiveTextColor};${ItalicFace}mActive interface${Reset}, ${ESC}${InactiveTextColor};${ItalicFace}mInactive interface${Reset}, ${ESC}${DisabledTextColor};${ItalicFace}mDisabled interface${Reset}\n"
printf "${ESC}${ItalicFace}mExplanation: ${ESC}${ActiveTextColor};${ItalicFace}mActive interface${Reset}, ${ESC}${InactiveTextColor};${ItalicFace}mInactive interface${Reset}, ${ESC}${DisabledTextColor};${ItalicFace}mDisabled interface${Reset}\n"
echo

# Print the title line
printf "${ESC}${UnderlineFace};${YellowFont}m${FormatStringInterfaces}${Reset}\n" "#" "Hardware Port" "Interface" "IPv4-address" "Config." "Subnet mask" "Router" "MAC-address" "Media Speed"

# Read the file and print the output
exec 4<"$NIfile"

while IFS=: read -u 4 IFNum IFName
do
  Interface="$(networksetup -listallhardwareports 2>/dev/null | grep -A1 "Hardware Port: $IFName" | tail -1 | awk '{print $2}')"
  # Ex: en0
  MediaSpeed="$(networksetup -getMedia "$IFName" 2>/dev/null | grep "^Active" | cut -d: -f2-)"
  # Ex: "1000baseT" or "autoselect"
  Configuration="$(networksetup -getinfo "$IFName" 2>/dev/null | grep Configuration | awk '{print $1}')"
  # Ex: "DHCP" or "Manual"
  IPaddress="$(networksetup -getinfo "$IFName" 2>/dev/null | grep "^IP address" | cut -d: -f2)"
  # Ex: " 130.235.16.211"
  SubnetMask="$(networksetup -getinfo "$IFName" 2>/dev/null | grep "^Subnet mask" | cut -d: -f2)"
  # Ex: " 255.255.254.0"
  Router="$(networksetup -getinfo "$IFName" 2>/dev/null | grep "^Router" | cut -d: -f2)"
  # Ex: " 130.235.16.1"
  #MACaddress="$(networksetup -getinfo "$IFName" | grep "^Ethernet Address" | cut -d: -f2-7)"
  MACaddress="$(ifconfig "$Interface" 2>/dev/null | grep "ether\ " | awk '{print $2}')"
  # Ex: " 00:3e:e1:be:06:59"
  Status="$(ifconfig  "$Interface" 2>/dev/null | grep "status:\ " | awk '{print $2}')"
  # Ex: "active"

  # Cludge to present VPN information
  # This has been tested with L2TP and it *seems* to work
  if [ "$(scutil --nc status "$IFName" 2>/dev/null | head -1)" = "Connected" ]; then
    Status="active"
    Interface="$(scutil --nc status "$IFName" | grep InterfaceName | cut -d: -f2 | sed 's/\ //')"
    IPaddress="$ppp_temp"
    Configuration="-"
    SubnetMask="$ppp_mask"
    Router="-"
    MACaddress="-"
    MediaSpeed="-"
    ppp_presented="t"
  fi

  # Set colors for printing)
  if [ "$IFNum" = "*" ]; then
    TextColor="${DisabledTextColor}"
  elif [ "$Status" = "active" ]; then
    TextColor="${ActiveTextColor}"
    [ "$IFName" = "Wi-Fi" ] && IFName="Wi-Fi (details below)"
  elif [ ! "$Status" = "active" ]; then
    TextColor="${InactiveTextColor}"
  fi
  printf "${ESC}${TextColor}m${FormatStringInterfaces}${Reset}\n" "$IFNum" "$IFName" "$Interface" "${IPaddress# }" "$Configuration" "${SubnetMask# }" "${Router# }" "${MACaddress# }" "${MediaSpeed}" 
done

# Print information about ppp (if any)
if [ -n "$ppp" -a -z "$ppp_presented" ]; then
  printf "${ESC}${ActiveTextColor}m${FormatStringInterfaces}${Reset}\n" "?" "-" "$ppp" "${ppp_temp}" "-" "${ppp_mask}" "-" "-" "-"
fi

# Print extra information about WiFi - if it is configured
# Get data with:
#  /System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I
# Sample output:
#      agrCtlRSSI: -51
#      agrExtRSSI: 0
#     agrCtlNoise: -87
#     agrExtNoise: 0
#           state: running
#         op mode: station 
#      lastTxRate: 104
#         maxRate: 144
# lastAssocStatus: 0
#     802.11 auth: open
#       link auth: wpa2-psk
#           BSSID: 58:98:35:37:8d:81
#            SSID: WppW
#             MCS: 13
#         channel: 1
#
# Values for signal strength and noice:
# Signal strength: -60: 5 bars  
#
# Signal Strength (*not* RSSI!!!):
# -80 dBm equals 10 pW of received radio power.
# -70 dBm equals 100 pW. This is 10 times stronger than -80 dBm.
# -60 dBm equals 1000 pW, or 1 nW. This is 10 times stronger than -70 dBm.
# -50 dBm equals 10000 pW, or 10 nW, or 10^-5 mW, or 0.00000001 W or 10^-8 W
# -40 dBm equals 100 nW, or 0.0001 mW, or 10^-7 W
# -30 dBm equals 1000 nW, or 0.001 mW, or 10^6 W, 0.000001 W
# -20 dBm equals 0.01 mW, or 10^5 W, or 0.00001 W
# -10 dBm equals 0.1 mW, 10^4 W, or 0.0001 W
#
# My own notices about RSSI:
# -73: still good (5 bars)
# -33: just next to the base station
# 
# Noice Level:     -82: low?    Should be 20 dB lover than the signal
# From: http://www.noah.org/wiki/WiFi_notes
# The Signal to Noise Ratio (SNR) in WiFi can be characterized by the following values:
#   >40   dB excellent signal; almost always full speed.
# 25 - 40 dB good signal; usually full speed, but may sometimes drop to lower speed.
# 15 - 25 dB moderate signal; fast, but not always full speed.
# 10 - 15 dB lowest useful signal; slow data speeds; may sometime loose association.
#   <10   dB AP may be detectable, but rarely useful signal; rarely maintains association.
# 
AP="/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I"
if [ ! "$(${AP})" = "AirPort: Off" ]; then
  # Gather information
  SSID="$(${AP} | grep "\ SSID" | cut -d: -f2- | sed 's/ //')"  # SSID=WppW
  Auth="$(${AP} | grep "link auth" | awk '{print $3}' | tr '[:lower:]' '[:upper:]')"  # Auth=WPA2-PSK
  MaxRate="$(${AP} | grep "maxRate" | awk '{print $2}') Mbps"   # MaxRate='144 Mbps'
  SignalStrength="$(${AP} | grep "agrCtlRSSI" | awk '{print $2}')" # SignalStrength=-44 
  Noice="$(${AP} | grep "agrCtlNoise" | awk '{print $2}')"   # Noice=-92
  Channel="$(${AP} | grep "channel" | awk '{print $2}')"    # Channel=1
  [ "${Channel%%,*}" -gt 15 ] && Frequency="5" || Frequency="2.4"
  
  # Calculate the Signal to Noice Ration and set a text for it
  SNR="$(expr $SignalStrength - $Noice)"
  if [ $SNR -gt 30 ]; then
    SNRText="Excellent"
  elif [ $SNR -gt 20 ]; then
    SNRText="Good"
  elif [ $SNR -gt 10 ]; then
    SNRText="Poor"
  else
    SNRText="Unusable"
  fi


  # Prepare the text blocks (it's easier this way)
  HeadBack="$BlueBack"
  HeadText="$WhiteFont"
  DataBack="$WhiteBack"
  DataText="$BlueFont"
  SSID_block="${ESC}${HeadBack};${HeadText}mSSID:${Reset}${ESC}${DataBack};${DataText}m ${SSID:- --no SSID chosen--} ${Reset}  "
  Auth_block="${ESC}${HeadBack};${HeadText}mAuth:${Reset}${ESC}${DataBack};${DataText}m ${Auth} ${Reset}  "
  Max_block="${ESC}${HeadBack};${HeadText}mMax Rate:${Reset}${ESC}${DataBack};${DataText}m ${MaxRate} ${Reset}  "
  Signal_block="${ESC}${HeadBack};${HeadText}mSignal Strength:${Reset}${ESC}${DataBack};${DataText}m ${SignalStrength} dB ${Reset}  "
  Noice_block="${ESC}${HeadBack};${HeadText}mNoice:${Reset}${ESC}${DataBack};${DataText}m ${Noice} dB ${Reset}  "
  QualityBlock="${ESC}${HeadBack};${HeadText}mQuality:${Reset}${ESC}${DataBack};${DataText}m ${SNRText} ${Reset}  "
  Channel_block="${ESC}${HeadBack};${HeadText}mChannel:${Reset}${ESC}${DataBack};${DataText}m ${Channel} ${Reset}  "
  Frequency_block="${ESC}${HeadBack};${HeadText}mFrequency:${Reset}${ESC}${DataBack};${DataText}m ${Frequency} GHz ${Reset} "

  # Print the information
  echo
  echo
  printf "${ESC}${WhiteFont};${BoldFace};${BlackBack}mWi-Fi details:${Reset}  \n"
  printf "${SSID_block}${Auth_block}${Max_block}${Signal_block}${Noice_block}${QualityBlock}${Channel_block}${Frequency_block}\n"
fi

# Clean up the $NSOfile
/bin/rm "$NIfile" 2>/dev/null

exit 0
