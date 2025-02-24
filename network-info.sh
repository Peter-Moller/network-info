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
VER="1.6"

help() {
    echo
    echo "Usage: $0 [-w]"
    echo
    echo "-w: Only show the wireless information."
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
while getopts ":hwd" opt; do
case $opt in
    w ) WiFiOnly=t;;
    d ) debug=t;;
 \?|h ) help;;
esac
done


# Find where the script resides. If it's a link, get *that* directory
if [ -L "${BASH_SOURCE[0]}" ]; then
    DirName="$(dirname $(readlink ${BASH_SOURCE[0]}))"
else
    DirName="$(dirname ${BASH_SOURCE[0]})"
fi
# What is the name of the script?
ScriptName="$(basename ${BASH_SOURCE[0]})"



# Basic settings:
# PREFIX points to where the data files are stored. 
DEFAULT_INTERFACE="$(netstat -rn | egrep -A3 "Internet:" | egrep "^default" | head -1 | awk '{print $NF}')"
MY_IP_ADDRESS="$(ifconfig $DEFAULT_INTERFACE | grep "inet " | awk '{ print $2 }')"
#DOMAIN="`ipconfig getpacket en0 | grep 'domain_name (string)' | awk '{ print $3 }'`"
DOMAIN="$(hostname | cut -d\. -f2-7)"
MTIME60m="-mtime -60m"
MTIME120m="-mtime +120m"
MTIME7d="-mtime -7d"
# NAT has content if we are on a private net (^192.168.|^172.16.|^10.) and empty otherwise
NAT="$(echo $MY_IP_ADDRESS | egrep "^192.168.|^172.16.|^10.")"

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


# ----------------------------------------------------------------------------------------------------
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



# Print the head
printf "${ESC}${BlackBack};${WhiteFont}mHostname:${ESC}${WhiteBack};${BlackFont}m $(hostname) ${Reset}   ${ESC}${BlackBack};${WhiteFont}mComputer Name:${ESC}${WhiteBack};${BlackFont}m ${ComputerName} ${Reset}   ${ESC}${BlackBack};${WhiteFont}mRunning:${ESC}${WhiteBack};${BlackFont}m $SW_VERS ${Reset}   ${ESC}${BlackBack};${WhiteFont}mDate & time:${ESC}${WhiteBack};${BlackFont}m $(date +%F", "%R) ${Reset}\n"
echo

# Print the wired network info only if WiFiOnly ≠ t
if [ ! "$WiFiOnly" = "t" ]; then
    # Get the info
    NetworkInfoFile="/tmp/NetworkInterfaces_$$.txt"
    # networksetup -listnetworkserviceorder  | grep -A 1 "^([0-9])\ " | grep "[a-z][0-9])$" | cut -d: -f2,3 | sed -e 's/, Device//g' -e 's/)//g' -e 's/^ //g' > $NSOfile
    networksetup -listnetworkserviceorder | egrep "^\([0-9\*]*\)\ " | sed -e 's/^(//g' -e 's/) /:/' | egrep -v "\*" > $NetworkInfoFile
    # Example:
    # 1:Bluetooth DUN
    # 2:Ethernet 1
    # 3:Ethernet 2
    # 4:Display Ethernet
    # 5:Display FireWire
    # 6:Wi-Fi
    # *:Bluetooth PAN
    # 7:Thunderbolt Bridge

    # Print the title line
    printf "${ESC}${ItalicFace}mExplanation: ${ESC}${ActiveTextColor};${ItalicFace}mActive interface${Reset}, ${ESC}${InactiveTextColor};${ItalicFace}mInactive interface${Reset}, ${ESC}${DisabledTextColor};${ItalicFace}mDisabled interface${Reset}\n"
    echo
    printf "${ESC}${UnderlineFace};${YellowFont}m${FormatStringInterfaces}${Reset}\n" "#" "Hardware Port" "Interface" "IPv4-address" "Config." "Subnet mask" "Router" "MAC-address" "Media Speed"

    # Read the file and print the output
    exec 4<"$NetworkInfoFile"
    while IFS=: read -u 4 IFNum IFName
    do
        # Determine of a VPN connection is active:
        # Sample output from the command: '* (Connected)      199F727B-C91D-4A6E-8A0B-4745179895F2 IPSec              "VPN (Cisco IPSec)"              [IPSec]'
        if [ -n "$(scutil --nc list | egrep "Connected")" -a "$IFName" = "$(scutil --nc list | egrep "Connected" | cut -d\" -f2)" ]; then
            Interface="$(netstat -rn | egrep -A3 "Internet:" | egrep default | head -1 | awk '{print $NF}')"
            # Ex: 'utun5'
            MediaSpeed="Unknown"
            Configuration="Unknown"
            IPaddress="$(ifconfig $Interface | egrep "\-\->" | awk '{print $4}')"
            # Ex: '10.190.1.1'
            SubnetMaskTemp="$(ifconfig $Interface | egrep "\-\->" | awk '{print $NF}' | sed -e 's/^0x//')"
            # Ex: 'ffffffff'
            SubNetP1="$(echo "ibase=16; $(echo $SubnetMaskTemp | cut -c1-2 | tr '[:lower:]' '[:upper:]')" | bc)"
            SubNetP2="$(echo "ibase=16; $(echo $SubnetMaskTemp | cut -c3-4 | tr '[:lower:]' '[:upper:]')" | bc)"
            SubNetP3="$(echo "ibase=16; $(echo $SubnetMaskTemp | cut -c5-6 | tr '[:lower:]' '[:upper:]')" | bc)"
            SubNetP4="$(echo "ibase=16; $(echo $SubnetMaskTemp | cut -c7-8 | tr '[:lower:]' '[:upper:]')" | bc)"
            SubnetMask="${SubNetP1}.${SubNetP2}.${SubNetP3}.${SubNetP4}"
            # Ex: '255.255.255.255'
            Router="Unknown"
            # Ex: " 130.235.16.1"
            #MACaddress="$(networksetup -getinfo "$IFName" | grep "^Ethernet Address" | cut -d: -f2-7)"
            MACaddress="Unknown"
            # Ex: " 00:3e:e1:be:06:59"
            Status="$(scutil --nc status "$IFName" | head -1)"
            # Ex: 'Connected'
        else
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
        fi

        # Set colors for printing)
        if [ "$IFNum" = "*" ]; then
            TextColor="${DisabledTextColor}"
        elif [ "$Status" = "active" -o "$Status" = "Connected" ]; then
            TextColor="${ActiveTextColor}"
            [ "$IFName" = "Wi-Fi" ] && IFName="Wi-Fi (details below)"
        elif [ ! "$Status" = "active" ]; then
            TextColor="${InactiveTextColor}"
        fi
        printf "${ESC}${TextColor}m${FormatStringInterfaces}${Reset}\n" "$IFNum" "$IFName" "$Interface" "${IPaddress# }" "$Configuration" "${SubnetMask# }" "${Router# }" "${MACaddress# }" "${MediaSpeed}"
    done
    echo
    # Clean up the $NSOfile
    /bin/rm "$NetworkInfoFile" 2>/dev/null

fi

# Print extra information about WiFi - if it is configured
# Get data with:
#  /System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I
# Sample output:
#      agrCtlRSSI: -51                 <-- Interesting
#      agrExtRSSI: 0
#     agrCtlNoise: -87                 <-- Interesting
#     agrExtNoise: 0
#           state: running
#         op mode: station 
#      lastTxRate: 104
#         maxRate: 144                 <-- Interesting
# lastAssocStatus: 0
#     802.11 auth: open
#       link auth: wpa2-psk            <-- Interesting
#           BSSID: 58:98:35:37:8d:81
#            SSID: WppW                <-- Interesting
#             MCS: 13
#         channel: 1                   <-- Interesting
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

# First, determine if WiFi is active:
WiFiDevice="$(networksetup -listallhardwareports | grep -A1 "^Hardware Port: Wi-Fi" | tail -1 | awk '{print $NF}')"         # Ex: WiFiDevice=en1
NetworkPower="$(networksetup -getairportpower $WiFiDevice | awk '{print $NF}')"                                             # Ex: NetworkPower=On
if [ "$NetworkPower" = "On" ]; then
    # See if we should use the old system:
    AP="$(/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I)"
    if [ -n "$(echo "$AP" | grep "AirPort: Off")" ]; then
        # Gather information
        SSID="$(echo "$AP" | grep "\ SSID" | cut -d: -f2- | sed 's/ //')"                                                   # SSID=WppW
        Auth="$(echo "$AP" | grep "link auth" | awk '{print $3}' | tr '[:lower:]' '[:upper:]')"                             # Auth=WPA2-PSK
        MaxRate="$(echo "$AP" | grep "maxRate" | awk '{print $2}') Mbps"                                                    # MaxRate='144 Mbps'
        SignalStrength="$(echo "$AP" | grep "agrCtlRSSI" | awk '{print $2}')"                                               # SignalStrength=-44
        Noice="$(echo "$AP" | grep "agrCtlNoise" | awk '{print $2}')"                                                       # Noice=-92
        Channel="$(echo "$AP" | grep "channel" | awk '{print $2}')"                                                         # Channel=1
        [ "${Channel%%,*}" -gt 15 ] && Frequency="5" || Frequency="2.4"
    # Else, use the modern approach
    elif [ -n "$(echo "$AP" | grep "WARNING: The airport command line tool is deprecated")" ]; then
        # Use 'system_profiler' to get WiFi details:
        # But only if 'jq' is present
        if type -p jq &>/dev/null; then
            printf "... investigating WiFi...\r"
            WiFiDetails="$(system_profiler -json SPAirPortDataType basic | jq --arg iface "$WiFiDevice" '.SPAirPortDataType[].spairport_airport_interfaces[] | select(._name == $iface) | .spairport_current_network_information')"
            printf "%25s" " "                                                                                               # Print 25 spaces to overwrite the previous text. Must add a '\r' later!
            # Ex:  WiFiDetails='{
            #      "_name": "eduroam",
            #      "spairport_network_channel": "52 (5GHz, 40MHz)",
            #      "spairport_network_country_code": "SE",
            #      "spairport_network_mcs": 9,
            #      "spairport_network_phymode": "802.11ac",
            #      "spairport_network_rate": 400,
            #      "spairport_network_type": "spairport_network_type_station",
            #      "spairport_security_mode": "spairport_security_mode_wpa2_enterprise",
            #      "spairport_signal_noise": "-66 dBm / -97 dBm"
            #    }'
            SSID="$(echo "$WiFiDetails" | jq -r '._name')"                                                                  # Ex: SSID=eduroam
            Auth="$(echo "$WiFiDetails"|jq -r '.spairport_security_mode'|rev|cut -d'_' -f1-2|rev|sed 's/_/ /;s/wpa/WPA/')"  # Ex: Auth='WPA2 enterprise'
            MaxRate="$(echo "$WiFiDetails" | jq -r '.spairport_network_rate')"                                              # Ex: MaxRate=400
            SignalStrength="$(echo "$WiFiDetails" | jq -r '.spairport_signal_noise' | awk '{print $1}')"                    # Ex: SignalStrength=-66
            Noice="$(echo "$WiFiDetails" | jq -r '.spairport_signal_noise' | cut -d\/ -f2 | awk '{print $1}')"              # Ex: Noice=-97
            Channel="$(echo "$WiFiDetails" | jq -r '.spairport_network_channel' | awk '{print $1}')"                        # Ex: Channel=52
            Frequency="$(echo "$WiFiDetails" | jq -r '.spairport_network_channel' | cut -d\( -f2 | grep -Eo "^[0-9.]")"     # Ex: Frequency=5
        else
            # OK, so then we will use 'wdutil' instead
            ### Note 1: requires 'sudo'
            ### Note 2: will NOT reveal SSID!
            if [ "$EUID" -eq 0 ]; then
                WDINFO="$(wdutil info | awk '/^WIFI/,/^BLUETOOTH/' | grep -E "^\s*RSSI\s*: |^\s*Noise\s*: |^\s*Tx Rate\s*: |^\s*Security\s*: |^\s*Channel\s*: |^\s*SSID\s*: ")"
                # WDINFO='    SSID                 : <redacted>
                #             RSSI                 : -64 dBm
                #             Noise                : -99 dBm
                #             Tx Rate              : 400.0 Mbps
                #             Security             : WPA2 Enterprise
                #             Channel              : 5g52/40'
                SSID="$(echo "$WDINFO" | grep "\ SSID" | cut -d: -f2- | sed 's/ //')"                                       # SSID='<redacted>'
                Auth="$(echo "$WDINFO" | grep "Security" | cut -d: -f2- | sed 's/ //')"                                     # Auth='WPA2 Enterprise'
                MaxRate="$(echo "$WDINFO" | grep "Tx Rate" | cut -d: -f2- | sed 's/ //')"                                   # MaxRate='400.0 Mbps'
                SignalStrength="$(echo "$WDINFO" | grep "RSSI" | awk '{print $3}')"                                         # SignalStrength=-64
                Noice="$(echo "$WDINFO" | grep "Noise" | awk '{print $3}')"                                                 # Noice=-99
                Channel="$(echo "$WDINFO" | grep "Channel" | cut -d\/ -f2)"                                                 # Channel=40
                if [ "$(echo "$WDINFO" | grep "Channel" |  cut -d: -f2 | cut -c2-3)" = "5g" ]; then
                    Frequency="5"
                else
                    Frequency="2.4"
                fi
            else
                echo "Command 'jq' not present and you are not running with superuser priviledges (needed by 'wdutil')"
                echo "So we cant displayu any information about WiFi. Sorry!"
                echo "(install 'jq' and try again!)"
                exit 0
            fi
        fi
    fi

    # Calculate the Signal to Noice Ration and set a text for it
    SNR="$(expr ${SignalStrength:-0} - ${Noice:-0})"
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
    printf "${ESC}${WhiteFont};${BoldFace};${BlackBack}m\rWi-Fi details:${Reset}  \n"
    printf "${SSID_block}${Auth_block}${Max_block}${Signal_block}${Noice_block}${QualityBlock}${Channel_block}${Frequency_block}\n"
fi

exit 0
