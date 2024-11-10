#!/bin/bash
# check for low quality drivers and combinations
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
# ------------------------------------------------------check_and_warn
WIRELESS_ADAPTER="wlan0"
# remove interfaces from managed list
if [[ -f /etc/hostapd.conf: ]]; then
    sed 's/interface-name:wl.*//' -i /etc/NetworkManager/conf.d/10-ignore-interfaces.conf
    sed 's/,$//' -i /etc/NetworkManager/conf.d/10-ignore-interfaces.conf
fi

# clear current settings
rm -f /etc/network/interfaces.d/armbian.ap.nat
rm -f /etc/network/interfaces.d/armbian.ap.bridge
service networking restart
service network-manager restart
{ for ((i = 0 ; i <= 100 ; i+=20)); do sleep 1; echo $i; done } | dialog --title " Initializing wireless adapters " --colors --gauge "" 5 50 0

# start with basic config
if grep -q "^## IEEE 802.11ac" /etc/hostapd.conf; then sed '/## IEEE 802.11ac\>/,/^## IEEE 802.11ac\>/ s/.*/#&/' -i /etc/hostapd.conf; fi
if grep -q "^## IEEE 802.11a" /etc/hostapd.conf; then sed '/## IEEE 802.11a\>/,/^## IEEE 802.11a\>/ s/.*/#&/' -i /etc/hostapd.conf; fi
if grep -q "^## IEEE 802.11n" /etc/hostapd.conf; then sed '/## IEEE 802.11n/,/^## IEEE 802.11n/ s/.*/#&/' -i /etc/hostapd.conf; fi
sed -i "s/^channel=.*/channel=5/" /etc/hostapd.conf

service network-manager reload
# change special adapters to AP mode
#---------------------------------------- wlan_exceptions "on"
# check for WLAN interfaces
#---------------------------------------- get_wlan_interface
# add interface to unmanaged list
if [[ -f /etc/NetworkManager/conf.d/10-ignore-interfaces.conf ]]; then
    [[ -z $(grep -w unmanaged-devices= /etc/NetworkManager/conf.d/10-ignore-interfaces.conf) ]] && sed '$ s/$/,/' -i /etc/NetworkManager/conf.d/10-ignore-interfaces.conf
    sed '$ s/$/'"interface-name:$WIRELESS_ADAPTER"'/' -i /etc/NetworkManager/conf.d/10-ignore-interfaces.conf
else
    echo "[keyfile]" > /etc/NetworkManager/conf.d/10-ignore-interfaces.conf
    echo "unmanaged-devices=interface-name:$WIRELESS_ADAPTER" >> /etc/NetworkManager/conf.d/10-ignore-interfaces.conf
fi
service network-manager reload
# display dialog
dialog --colors --backtitle "$BACKTITLE" --title "Please wait" --infobox \
"\nWireless adapter: \Z1${WIRELESS_ADAPTER}\Z0\n\nProbing nl80211 hostapd driver compatibility." 7 50
debconf-apt-progress -- apt-get --reinstall -o Dpkg::Options::="--force-confnew" -y -qq --no-install-recommends install hostapd
# change to selected interface
sed -i "s/^interface=.*/interface=$WIRELESS_ADAPTER/" /etc/hostapd.conf
# add hostapd.conf to services
sed -i "s/^DAEMON_CONF=.*/DAEMON_CONF=\/etc\/hostapd.conf/" /etc/init.d/hostapd
# check both options
# add allow cli access if not exists. temporally
if ! grep -q "ctrl_interface" /etc/hostapd.conf; then
    echo "" >> /etc/hostapd.conf
    echo "ctrl_interface=/var/run/hostapd" >> /etc/hostapd.conf
    echo "ctrl_interface_group=0" >> /etc/hostapd.conf
fi
#
#---------------------------------------------check_advanced_modes
#
# if [[ -n "$hostapd_error" ]]; then
#     dialog --colors --backtitle "$BACKTITLE" --title "Please wait" --infobox \
#     "\nWireless adapter: \Z1${WIRELESS_ADAPTER}\Z0\n\nProbing Realtek hostapd driver compatibility." 7 50
#     debconf-apt-progress -- apt-get --reinstall -o Dpkg::Options::="--force-confnew" -y -qq --no-install-recommends install hostapd-realtek
#     # change to selected interface
#     sed -i "s/^interface=.*/interface=$WIRELESS_ADAPTER/" /etc/hostapd.conf
#     # add allow cli access if not exists. temporally
#     if ! grep -q "ctrl_interface" /etc/hostapd.conf; then
#         echo "ctrl_interface=/var/run/hostapd" >> /etc/hostapd.conf
#         echo "ctrl_interface_group=0" >> /etc/hostapd.conf
#     fi
#     #
#     check_advanced_modes
#     #
# fi

# if [[ -n "$hostapd_error" ]]; then
#     dialog --backtitle "$BACKTITLE" --title "Warning" \
#     --infobox "\nWireless adapter: $WIRELESS_ADAPTER\n\nNo compatible hostapd driver found." 7 39
#     sed -i "s/^DAEMON_CONF=.*/DAEMON_CONF=/" /etc/init.d/hostapd
#     # remove interfaces from managed list
#     sed 's/interface-name:wl.*//' -i /etc/NetworkManager/conf.d/10-ignore-interfaces.conf
#     sed 's/,$//' -i /etc/NetworkManager/conf.d/10-ignore-interfaces.conf
#     systemctl daemon-reload;service hostapd restart
# fi

# let's remove bridge out for this simple configurator
#
# dialog --title " Choose Access Point mode for $WIRELESS_ADAPTER " --colors --backtitle "$BACKTITLE" --no-label "Bridge" \
# --yes-label "NAT" --yesno "\n\Z1NAT:\Z0 with own DHCP server, out of your primary network\n\
# \n\Z1Bridge:\Z0 wireless clients will use your routers DHCP server" 9 70
# response=$?
#
# let's remove bridge out for this simple configurator

# response=0

# create interfaces file if not exits
[[ ! -f /etc/network/interfaces ]] && echo "source /etc/network/interfaces.d/*" > /etc/network/interfaces

# select default interfaces if there is more than one
#--------------------------------------select_default_interface

NETWORK_CONF="/etc/network/interfaces"

TEMP_CONF="/etc/network/interfaces.d/armbian.ap.nat"

# install dnsmas and iptables
if [[ $(dpkg-query -W -f='${db:Status-Abbrev}\n' dnsmasq 2>/dev/null) != "*ii*" ]]; then
    debconf-apt-progress -- apt-get -qq -y --no-install-recommends install dnsmasq iptables
    systemctl enable dnsmasq
fi

echo -e "# armbian NAT hostapd\nallow-hotplug $WIRELESS_ADAPTER\niface $WIRELESS_ADAPTER inet static " > $TEMP_CONF
echo -e "\taddress 172.24.1.1\n\tnetmask 255.255.255.0\n\tnetwork 172.24.1.0\n\tbroadcast 172.24.1.255" >> $TEMP_CONF
# create new configuration
echo "interface=$WIRELESS_ADAPTER				# Use interface $WIRELESS_ADAPTER" > /etc/dnsmasq.conf
echo "listen-address=172.24.1.1					# Explicitly specify the address to listen on" >> /etc/dnsmasq.conf
echo "bind-interfaces							# Bind to the interface to make sure we aren't sending \
things elsewhere" >> /etc/dnsmasq.conf
echo "server=8.8.8.8							# Forward DNS requests to Google DNS" >> /etc/dnsmasq.conf
echo "domain-needed								# Don't forward short names" >> /etc/dnsmasq.conf
echo "bogus-priv								# Never forward addresses in the non-routed address spaces" \
>> /etc/dnsmasq.conf
echo "dhcp-range=172.24.1.50,172.24.1.150,12h	# Assign IP addresses between 172.24.1.50 and 172.24.1.150 with \
a 12 hour lease time" >> /etc/dnsmasq.conf
# - Enable IPv4 forwarding
sed -i "/net.ipv4.ip_forward=/c\net.ipv4.ip_forward=1" /etc/sysctl.conf
echo 1 > /proc/sys/net/ipv4/ip_forward
# Clear iptables
iptables-save | awk '/^[*]/ { print $1 } /^:[A-Z]+ [^-]/ { print $1 " ACCEPT" ; } /COMMIT/ { print $0; }' | iptables-restore
# - Apply iptables
iptables -t nat -A POSTROUTING -o $WIRELESS_ADAPTER -j MASQUERADE
iptables -A FORWARD -i $WIRELESS_ADAPTER -o $WIRELESS_ADAPTER -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $WIRELESS_ADAPTER -o $WIRELESS_ADAPTER -j ACCEPT
# - Save IP tables, applied during ifup in /etc/network/interfaces.
iptables-save > /etc/iptables.ipv4.nat
sed -i 's/^bridge=.*/#&/' /etc/hostapd.conf
#sed -e 's/exit 0//g' -i /etc/rc.local
# workaround if hostapd is too slow
#echo "service dnsmasq start" >> /etc/rc.local
#echo "iptables-restore < /etc/iptables.ipv4.nat" >> /etc/rc.local
#echo "exit 0" >> /etc/rc.local
systemctl stop armbian-restore-iptables.service
systemctl disable armbian-restore-iptables.service
cat <<-EOF > /etc/systemd/system/armbian-restore-iptables.service
[Unit]
Description="Restore IP tables"
[Timer]
OnBootSec=20Sec
[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables.ipv4.nat
[Install]
WantedBy=sysinit.target
EOF
systemctl enable armbian-restore-iptables.service
# reload services
reload-nety "reload"
reboot
