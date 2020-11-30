#!/bin/bash

# <bitbar.title>keyrace</bitbar.title>
# <bitbar.version>v0.1</bitbar.version>
# <bitbar.author>Nat Friedman</bitbar.author>
# <bitbar.author.github>nat</bitbar.author.github>
# <bitbar.desc>Show keys typed today</bitbar.desc>
# <bitbar.image>http://i.imgur.com/qaIxpJN.png</bitbar.image> <!-- fix me -->


KEYCOUNT=`cat /tmp/keyrace.tmp`
export LC_NUEMRIC=en_US
KC_FORMATTED=`printf "%'.f\n" $KEYCOUNT`
echo "$KC_FORMATTED keypresses today"
echo ---
output=$(curl http://159.89.136.69/leaderboard?team=default 2> /dev/null)
while IFS= read -r line; do
	echo "$line | size=14 font=Courier"
done <<< "$output" | column -t -s $'\t'
