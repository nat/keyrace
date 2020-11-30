#!/bin/bash

# <bitbar.title>keyrace</bitbar.title>
# <bitbar.version>v0.1</bitbar.version>
# <bitbar.author>Nat Friedman</bitbar.author>
# <bitbar.author.github>nat</bitbar.author.github>
# <bitbar.desc>Show keys typed today</bitbar.desc>
# <bitbar.image>http://i.imgur.com/qaIxpJN.png</bitbar.image> <!-- fix me -->


echo "[ `cat /tmp/keyrace.tmp` keys ]"
echo ---
curl http://159.89.136.69/leaderboard?team=default 2> /dev/null
