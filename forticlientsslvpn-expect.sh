#!/bin/bash

# Forticlient SSL VPN Client launching script utilizing expect.

# --------------------------------------------
# CONFIGURATION

# If empty - script will take some simple logic to locate appropriate binary.
FORTICLIENT_PATH="/root/forticlientsslvpn/64bit/forticlientsslvpn_cli"

# VPN Credentials
VPN_HOST=""
VPN_USER=""
VPN_PASS=""

# --------------------------------------------

trap ctrl_c INT

function ctrl_c() {
  echo "Removing left-over files..."
  rm -f /tmp/expect
}

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

if [ -z "$FORTICLIENT_PATH" ]; then
  FORTICLIENT_PATH=`uname -r | grep -q 64 && echo $(locate forticlientsslvpn_cli | grep 64bit) || echo $(locate forticlientsslvpn_cli | grep 32bit)`
  if [ ! -f $FORTICLIENT_PATH ]; then
    echo "Tried to locate Forticlient SSL VPN Cli binary, but failed."
    echo "Specify it at variable FORTCLIENT_PATH"
    exit 1
  fi
  echo "Located Forticlient VPN Client at: $FORTICLIENT_PATH"
fi

echo "Killing previous instances of Forticlient SSL VPN client..."
killall -9 $(basename $FORTICLIENT_PATH) 2> /dev/null

cat << EOF > /tmp/expect
#!/usr/bin/expect -f
match_max 1000000
set timeout -1
spawn $FORTICLIENT_PATH --server $VPN_HOST --vpnuser $VPN_USER --keepalive
expect "Password for VPN:"
send -- "$VPN_PASS"
send -- "\r"

expect "Would you like to connect to this server? (Y/N)"
send -- "Y"
send -- "\r"

expect "Clean up..."
close
EOF

chmod 500 /tmp/expect
/usr/bin/expect -f /tmp/expect & 

while [[ ! $(route -n | grep ppp | awk '{print $1}') == '0.0.0.0' ]]
do
	echo "VPN is not ready"
	sleep 3
done	
echo "Routing setup ..."
GW=$(route -n | grep ppp | awk '{print $2}')
VPN_INTERFACE=$(route -n | grep ppp | awk '{print $8}')
route add -net 172.16.0.0 netmask 255.255.0.0 dev ${VPN_INTERFACE} metric 200
route del -net default gw ${GW} netmask 0.0.0.0 dev ${VPN_INTERFACE} metric 0

