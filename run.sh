#!/usr/bin/env bash

mkdir -p logs/

# -----------------------------------------------------------------------------
# PRETTY PRINTING
# -----------------------------------------------------------------------------
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
blue='\033[0;34m'
nc='\033[0m'

# Print something in color. First argument is the text, second argument is the color
echoc() {
	printf "$2%s$nc\n" "$1"
}
_print() {
	printf '[ .... ] %s' "$1"
}
_ok() {
	printf "\r[$green DONE $nc]\n"
}
_warn() {
	printf "\r[$yellow WARN $nc] %s\n" "$1"
}
_err() {
	printf "\r[$red FAIL $nc]"
	[ -n "$2" ] && printf " %s\n" "$1" || printf "\n%s\n" "$1"
	exit 1
}
# $1: command to handle
# $2: (optional) log file to save command output to
# $3: (optional) '-' to put an '&' after command for continuous output
_handle() {
	if [ -n "$2" ]; then
		[ -n "$3" ] && {
			$1 &>logs/$2 &
			sleep 3
		} || $1 &>logs/$2
		if [ $? = 0 ]; then
			_ok
			echoc "Log: file://$(pwd)/logs/$2" $blue
		else 
			_err "$(cat logs/$2 | tail -n 10)"
		fi
	else
		err_msg="$($1 2>&1 >/dev/null)"
		[ $? -eq 0 ] && _ok || _err "$err_msg"
	fi	
}

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------
display_help() {
	echoc '-----------------------------------------------' $blue
	echoc '|           HOW TO USE THIS SCRIPT            |' $blue
	echoc '-----------------------------------------------' $blue
	echoc './run.sh <function> <options>' $yellow
	echo '    <function> (required) is exactly one of the primary flags listed below'
	echo '    <options>  (optional) is any combination of the indented flags below a primary flag'
	echo ''
	echo '--help    [-h]: Show this help menu'
	echo '--serial  [-s]: View serial monitor'
	echo '--compile [-c]: Compile the arduino code'
	echo '--upload  [-u]: Upload the project to an arduino device connected via USB'
	echo '    --debug [-d]: Display serial output in the command prompt. Use ctrl^a + ctrl^d to exit.'
	echo ''
	echoc '*If no arguments are supplied, this help menu is displayed' $yellow
}
get_usb_device() {
	# grab the origin of the symlink for a USB device with 'CP2102' in it's id. If it couldn't be found, throw an error
	# 'CP2102' just means arduino can write WiFi libraries to the device
	USB_DEVICE=$(readlink -f /dev/serial/by-id/*CP2102* | head -n 1)
	[ -z "$USB_DEVICE" ] && _err 'Could not find a USB device with the CP2102 driver' -

	# Ensure that everybody has read/write privileges on the USB device
	[ $(stat -c '%a' $USB_DEVICE) -eq 666 ] || {
		_warn "$USB_DEVICE is not writable. Entering root environment to alter USB permissions"
		sudo chmod 666 $USB_DEVICE
	}
}
kill_usb_proc() {
	_print 'Killing previous USB processes'
	sudo fuser -k $USB_DEVICE &>/dev/null
	_ok
}
view_serial() {
	req_check screen
	sudo rm -f screenlog.0
	sudo screen -L $USB_DEVICE 9600
	sudo chown $USER:$USER screenlog.0
	mv screenlog.0 logs/serial.log
	echoc "Log: file://$(pwd)/logs/serial.log" $blue
}
escalate_privileges() {
	sudo printf ''
}
get_wifi_credentials() {
	read -p 'Enter your WiFi ssid (name): ' WIFI_ID
	echo "WIFI_ID=$WIFI_ID" > src/wifi.secret
	read -p 'Enter your WiFi password: ' WIFI_PASSWORD
	echo "WIFI_PASSWORD=$WIFI_PASSWORD" >> src/wifi.secret
}

# -----------------------------------------------------------------------------
# PRIMARY FUNCTIONS
# -----------------------------------------------------------------------------
compile_project() {
	parse_wifi_credentials
	_print 'Compiling your code'
	_handle "arduino -v --verify --board esp8266:esp8266:nodemcu --port $USB_DEVICE src/controller.cpp" compile.log
}
upload_project() {
	escalate_privileges
	kill_usb_proc
	parse_wifi_credentials

	# We need this warning here because the 'screen' command is very difficult to exit if you don't know how
	[ -n "$DEBUG" ] && _warn 'Debug mode enabled. Use ctrl^a + ctrl^d to exit when output begins'

	_print "Uploading to $USB_DEVICE"
	_handle "arduino -v --upload --board esp8266:esp8266:nodemcu --port $USB_DEVICE src/controller.cpp" upload.log

	[ -n "$DEBUG" ] && view_serial
}
first_time_setup() {
	_print 'Adding ESP8266 board url'
	_handle 'arduino --pref "boardsmanager.additional.urls=http://arduino.esp8266.com/stable/package_esp8266com_index.json" --save-prefs'

	_print 'Installing ESP8266 board'
	_handle 'arduino --install-boards esp8266:esp8266 --save-prefs'
}

# -----------------------------------------------------------------------------
# REQUIREMENT CHECKING
# -----------------------------------------------------------------------------
req_check() {
	# Absolute requirements + any requirements passed via arguments
	reqs=(arduino $@)
	err=()
	for i in ${reqs[@]}; do
		command -v $i &>/dev/null || err+=($i)
	done
	[ ${#err[@]} -ne 0 ] && _err "You must install the following package(s): ${err[*]}" -

	# If the esp8266 board could not be found, run through the first time setup function
	arduino --board esp8266:esp8266:nodemcu &>/dev/null || first_time_setup
}

# Our requirements check will remain here until this project requires more software to build
req_check

# Grab our USB device location. This is global because every function relies on it
get_usb_device

[[ "$*" == *--debug* || "$*" == *-d* ]] && DEBUG=1

PRIMARY_TAG="$1"
shift
case $PRIMARY_TAG in
	--compile | -c)
		compile_project;;
	--upload | -u )
		upload_project;;
	--serial | -s)
		view_serial;;
	'')
		display_help;;
	*)
		display_help
		_err "Invalid argument: $PRIMARY_TAG" -;;
esac
