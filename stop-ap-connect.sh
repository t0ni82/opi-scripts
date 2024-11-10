#!/bin/bash
#
# reload network related services
#
function reload-nety() {

	systemctl daemon-reload
	(service network-manager stop; echo 10; sleep 1; service hostapd stop; echo 20; sleep 1; service dnsmasq stop; echo 30; sleep 1;\
	[[ "$1" == "reload" ]] && service dnsmasq start && echo 60 && sleep 1 && service hostapd start && echo 80 && sleep 1;\
	service network-manager start; echo 90; sleep 5;)
	systemctl restart systemd-resolved.service
}

# Define the wireless adapter variable
WIRELESS_ADAPTER="wlan0"
sed -i "s/^DAEMON_CONF=.*/DAEMON_CONF=/" /etc/init.d/hostapd
# disable DNS
systemctl daemon-reload
systemctl disable dnsmasq.service >/dev/null 2>&1

ifdown $WIRELESS_ADAPTER 2> /dev/null
rm -f /etc/network/interfaces.d/armbian.ap.*
rm -f /etc/dnsmasq.conf
iptables -t nat -D POSTROUTING 1 >/dev/null 2>&1
rm -f /etc/iptables.ipv4.nat
systemctl stop armbian-restore-iptables.service
systemctl disable armbian-restore-iptables.service	
rm -f /var/run/hostapd/* >/dev/null 2>&1
sed -i '/^iptables/ d' /etc/rc.local
sed -i '/^service dnsmasq/ d' /etc/rc.local
sed 's/interface-name:wl.*//' -i /etc/NetworkManager/conf.d/10-ignore-interfaces.conf
sed 's/,$//' -i /etc/NetworkManager/conf.d/10-ignore-interfaces.conf
iptables -F

# Check if SSID and password were provided as arguments
if [[ -n "$1" && -n "$2" ]]; then
	SSID="$1"
	PASSWORD="$2"
	echo "Attempting to connect to Wi-Fi network '$SSID'..."

	# Try to connect to the specified Wi-Fi network using nmcli
	nmcli device wifi connect "$SSID" password "$PASSWORD" iface "$WIRELESS_ADAPTER"
	
	if [[ $? -eq 0 ]]; then
		echo "Connected to Wi-Fi network '$SSID' successfully."
	else
		echo "Failed to connect to Wi-Fi network '$SSID'."
	fi
else
	echo "No SSID and password provided. Skipping Wi-Fi connection attempt."
fi

# reload services
reload-nety

