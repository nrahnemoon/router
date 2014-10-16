uci delete network.loopback
uci delete network.lan
uci delete network.modem

uci set network.loopback=interface
uci set network.loopback.ifname=lo
uci set network.loopback.proto=static
uci set network.loopback.ipaddr=127.0.0.1
uci set network.loopback.netmask=255.0.0.0
uci set network.lan=interface
uci set network.lan.ifname=eth0
uci set network.lan.type=bridge
uci set network.lan.proto=static
uci set network.lan.gateway=192.168.1.1
uci set network.lan.dns=192.168.1.1
# set $ipaddr variable to 192.168.1.7 if $RT_IPADDR is empty
[ ! -z "$RT_IPADDR" ] && ipaddr=$RT_IPADDR || ipaddr=192.168.1.7
uci set network.lan.ipaddr=$ipaddr

uci set network.lan.netmask=255.255.255.0
uci set network.modem=interface
uci set network.modem.ifname=eth1
uci set network.modem.proto=static
uci set network.modem.ipaddr=192.168.1.1
uci set network.modem.netmask=255.255.255.0

uci commit network
/etc/init.d/network restart

