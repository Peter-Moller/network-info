# network-info
A bash script for OS X that details information about the network

More details about the script can be found here:
http://cs.lth.se/peter-moller/script/network-info-en/

-----

Overview of how the script works:
---------------------------------

Default interface is found with `route get www.lu.se`

Data is gathered using the commands `ifconfig`, `networksetup` and `scutil`. The latter is used for VPN, but the solutions is not entirely satisfying.

One of the more useful parts of the script is the “Quality” assessment of the wireless network. This is calculated by subtract the noice level from the signal strength and then apply the following labels to the difference:

| Difference | Assessment |
|------------|------------|
| \>30:      | Excellent  |
| 20-30:     | Good       |
| 10-20:     | Poor       |
| <10:       | Unusable   |
