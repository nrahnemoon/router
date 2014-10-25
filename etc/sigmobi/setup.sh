# Load logger utility function
source /etc/sigmobi/logger.sh

log "Deleting previous settings"
rm -f /etc/config/wireless
rm -f /etc/config/network
rm -f /etc/config/dhcp
rm -f /etc/config/firewall
touch /etc/config/wireless
touch /etc/config/network
touch /etc/config/dhcp
touch /etc/config/firewall

log "Setting default wifi settings"
wifi detect > /etc/config/wireless

log "Delete all the default wifi interfaces"
while `uci show wireless | grep -q wifi-iface`; do
	uci delete wireless.@wifi-iface[0]
done

log "Setting home loopback"
uci set network.loopback=interface
uci set network.loopback.ifname=lo
uci set network.loopback.proto=static
uci set network.loopback.ipaddr=127.0.0.1
uci set network.loopback.netmask=255.0.0.0
uci commit network

log "Setting up default dnsmasq settings"
uci add dhcp dnsmasq
uci set dhcp.@dnsmasq[-1].domainneeded=1
uci set dhcp.@dnsmasq[-1].boguspriv=1
uci set dhcp.@dnsmasq[-1].filterwin2k=0
uci set dhcp.@dnsmasq[-1].localise_queries=1
uci set dhcp.@dnsmasq[-1].rebind_protection=1
uci set dhcp.@dnsmasq[-1].rebind_localhost=1
uci set dhcp.@dnsmasq[-1].local=/lan/
uci set dhcp.@dnsmasq[-1].domain=lan
uci set dhcp.@dnsmasq[-1].expandhosts=1
uci set dhcp.@dnsmasq[-1].nonegcache=0
uci set dhcp.@dnsmasq[-1].authoritative=1
uci set dhcp.@dnsmasq[-1].readethers=1
uci set dhcp.@dnsmasq[-1].leasefile=/tmp/dhcp.leases
uci set dhcp.@dnsmasq[-1].resolvfile=/tmp/resolv.conf.auto
uci commit dhcp

log "Add ODHCPD settings to enable IPv6 DHCP"
uci set dhcp.odhcpd=odhcpd
uci set dhcp.odhcpd.maindhcp=0
uci set dhcp.odhcpd.leasefile=/tmp/hosts/odhcpd
uci set dhcp.odhcpd.leasetrigger=/usr/sbin/odhcpd-update
uci commit dhcp

log "Commit default DHCP settings"
/etc/init.d/dnsmasq reload

log "Setup default firewall settings"
uci add firewall defaults
uci set firewall.@defaults[-1].syn_flood=1
uci set firewall.@defaults[-1].input=ACCEPT
uci set firewall.@defaults[-1].output=ACCEPT
uci set firewall.@defaults[-1].forward=REJECT
uci commit firewall

log "Commit default firewall settings"
/etc/init.d/firewall restart

log "Setting up the WAN network"
uci set network.wan=interface
uci set network.wan.proto=dhcp
uci commit network

log "Setting up WAN DHCP settings"
uci set dhcp.wan=dhcp
uci set dhcp.wan.interface=wan
uci set dhcp.wan.ignore=1
uci commit dhcp

log "Setting up WAN zone firewall settings"
uci add firewall zone
uci set firewall.@zone[-1].name=wan
uci set firewall.@zone[-1].network=wan
uci set firewall.@zone[-1].input=REJECT
uci set firewall.@zone[-1].output=ACCEPT
uci set firewall.@zone[-1].forward=REJECT
uci set firewall.@zone[-1].masq=1
uci set firewall.@zone[-1].mtu_fix=1
uci commit firewall

log "Commit WAN firewall settings"
/etc/init.d/firewall restart

log "Restarting the network with only wan and loopback"
/etc/init.d/network restart
/etc/init.d/dnsmasq reload

log "Setting up the wireless device interface"
uci set wireless.radio0.channel=11
uci set wireless.radio0.txpower=30
uci set wireless.radio0.disabled=0
uci commit wireless

log "Setting up the wifi client"
uci add wireless wifi-iface
uci set wireless.@wifi-iface[-1]=wifi-iface
uci set wireless.@wifi-iface[-1].device=radio0
uci set wireless.@wifi-iface[-1].network=wan
uci set wireless.@wifi-iface[-1].mode=sta
uci set wireless.@wifi-iface[-1].ssid=2WIRE230
uci set wireless.@wifi-iface[-1].encryption=psk-mixed
uci set wireless.@wifi-iface[-1].key=w1r3l3ss
uci commit wireless

log "Restarting the wifi with as only a client"
wifi

log "Waiting until wifi connected to get gateway information"
gateway="$(route -n | grep 'UG[ \t]' | awk '{print $2}')"
while [ -z "$gateway" ]; do
	sleep 1
	gateway="$(route -n | grep 'UG[ \t]' | awk '{print $2}')"
done
log "Succesfully connected to wifi with gateway $gateway"

log "Setting up the LAN network"
uci set network.lan=interface
uci set network.lan.ifname=eth0
uci set network.lan.type=bridge
uci set network.lan.proto=static
uci set network.lan.dns=$gateway
uci set network.lan.gateway=$gateway
# set $ipaddr variable to 192.168.2.7 if $RT_IPADDR is empty
[ ! -z "$RT_IPADDR" ] && ipaddr=$RT_IPADDR || ipaddr=192.168.2.7
uci set network.lan.ipaddr=$ipaddr
uci set network.lan.netmask=255.255.255.0
uci commit network

log "Setting up LAN DHCP settings"
uci set dhcp.lan=dhcp
uci set dhcp.lan.interface=lan
uci set dhcp.lan.start=100
uci set dhcp.lan.limit=150
uci set dhcp.lan.leasetime=1h
uci set dhcp.lan.dhcpv6=server
uci set dhcp.lan.ra=server
uci commit dhcp

log "Setting LAN zone firewall settings"
uci add firewall zone
uci set firewall.@zone[-1].name=lan
uci set firewall.@zone[-1].network=lan
uci set firewall.@zone[-1].input=REJECT
uci set firewall.@zone[-1].output=ACCEPT
uci set firewall.@zone[-1].forward=REJECT
uci commit firewall

log "Setting LAN to WAN firewall forwarding settings"
uci add firewall forwarding
uci set firewall.@forwarding[-1].src=lan
uci set firewall.@forwarding[-1].dest=wan
uci commit firewall

log "Add firewall rule to allow DNS traffic on LAN independent of other rules"
uci add firewall rule
uci set firewall.@rule[-1].name=Allow-DNS-Queries
uci set firewall.@rule[-1].src=lan
uci set firewall.@rule[-1].dest_port=53
uci set firewall.@rule[-1].proto=tcpudp
uci set firewall.@rule[-1].target=ACCEPT
uci commit firewall

log "Add firewall rule to allow Internet DNS queries from the LAN to the WAN gateway"
uci add firewall rule
uci set firewall.@rule[-1].name=Internet-DNS
uci set firewall.@rule[-1].src=lan
uci set firewall.@rule[-1].dest=wan
uci set firewall.@rule[-1].dest_ip=$gateway
uci set firewall.@rule[-1].dest_port=53
uci set firewall.@rule[-1].proto=tcpudp
uci set firewall.@rule[-1].target=ACCEPT
uci commit firewall

log "Add firewall rule to drop all traffic going from the LAN subnet to the WAN subnet"
subnet="$(route -n | grep 'U[ \t]' | grep wlan0 | awk '{print $1}')"
subnet_mask="$(route -n | grep 'U[ \t]' | grep wlan0 | awk '{print $3}')"
uci add firewall rule
uci set firewall.@rule[-1].name=Drop-Private-IP
uci set firewall.@rule[-1].src=lan
uci set firewall.@rule[-1].dest=wan
uci set firewall.@rule[-1].proto=all
uci set firewall.@rule[-1].target=DROP
uci set firewall.@rule[-1].dest_ip=$subnet/$subnet_mask
uci commit firewall

log "Add firewall rule to allow DHCP traffic on the LAN."
uci add firewall rule
uci set firewall.@rule[-1].name=Allow-LAN-DHCP-request
uci set firewall.@rule[-1].src=lan
uci set firewall.@rule[-1].src_port=67-68
uci set firewall.@rule[-1].dest_port=67-68
uci set firewall.@rule[-1].proto=udp
uci set firewall.@rule[-1].target=ACCEPT
uci commit firewall

log "Add firewall rule to allow DHCP traffic on the WAN."
uci add firewall rule
uci set firewall.@rule[-1].name=Allow-WAN-DHCP-request
uci set firewall.@rule[-1].src=wan
uci set firewall.@rule[-1].src_port=67-68
uci set firewall.@rule[-1].dest_port=67-68
uci set firewall.@rule[-1].proto=udp
uci set firewall.@rule[-1].target=ACCEPT
uci commit firewall

# DELETE THIS BEFORE PROD -- AUTOSSH WILL BE SETUP
log "Add firewall rule to allow SSH traffic on LAN independent of other rules"
uci add firewall rule
uci set firewall.@rule[-1].name=Allow-SSH-in
uci set firewall.@rule[-1].src=lan
uci set firewall.@rule[-1].dest_port=22
uci set firewall.@rule[-1].proto=tcp
uci set firewall.@rule[-1].target=ACCEPT
uci commit firewall

log "Add firewall rule to allow LAN clients to ping the router."
uci add firewall rule
uci set firewall.@rule[-1].name=Allow-Ping
uci set firewall.@rule[-1].src=lan
uci set firewall.@rule[-1].proto=icmp
uci set firewall.@rule[-1].icmp_type=echo-request
uci set firewall.@rule[-1].family=ipv4
uci set firewall.@rule[-1].target=ACCEPT
uci commit firewall

log "Add firewall rule to allow iPerf traffic on the LAN."
uci add firewall rule
uci set firewall.@rule[-1].name=Allow-iPerf-in
uci set firewall.@rule[-1].src=lan
uci set firewall.@rule[-1].dest_port=5001
uci set firewall.@rule[-1].proto=tcp
uci set firewall.@rule[-1].target=ACCEPT
uci commit firewall

log "Commit LAN firewall settings"
/etc/init.d/firewall restart

log "Restarting the network interfaces with the LAN network"
/etc/init.d/network restart
/etc/init.d/dnsmasq reload

log "Creating the wifi AP for the LAN network"
uci add wireless wifi-iface
uci set wireless.@wifi-iface[-1]=wifi-iface
uci set wireless.@wifi-iface[-1].device=radio0
uci set wireless.@wifi-iface[-1].network=lan
uci set wireless.@wifi-iface[-1].mode=ap
uci set wireless.@wifi-iface[-1].ssid=rt7
uci set wireless.@wifi-iface[-1].encryption=psk-mixed
uci set wireless.@wifi-iface[-1].isolate=1
uci set wireless.@wifi-iface[-1].key=t3st1234
uci commit wireless

log "Restarting wifi to create the LAN AP"
wifi

