#!/bin/sh

## DNS redirect configuration variables:
IPV4_IP="192.168.3.2"
IPV4_PORT=53
IPV4_SOURCE_ALLOWLIST="192.168.1.2,192.168.1.3,192.168.3.2,192.168.3.3"
IPV4_DESTINATION_ALLOWLIST=${IPV4_SOURCE_ALLOWLIST}
# Leave this blank if you don't use IPv6
IPV6_IP=""
IPV6_PORT=53
IPV6_SOURCE_ALLOWLIST=""
IPV6_DESTINATION_ALLOWLIST=""

# Set this to the interfaces you want to force through the DNS IP.
# Separate interfaces with spaces.
# e.g. "br0" or "br0 br1" etc.
FORCED_INTFC="br0"

# IPv4 force DNS (TCP/UDP 53) through DNS container
for intfc in ${FORCED_INTFC}; do
  if [ -d "/sys/class/net/${intfc}" ]; then
    for proto in udp tcp; do
      LOG_PREFIX="[DNAT-${intfc}-${proto}]"

      # source/destination allowlist handling (perhaps this could be 1 rule?)
      prerouting_rule="PREROUTING -i ${intfc} -p ${proto} -s ${IPV4_SOURCE_ALLOWLIST} --dport 53 -j RETURN"
      iptables -t nat -C ${prerouting_rule} 2>/dev/null || iptables -t nat -A ${prerouting_rule}
      prerouting_rule="PREROUTING -i ${intfc} -p ${proto} -d ${IPV4_DESTINATION_ALLOWLIST} --dport 53 -j RETURN"
      iptables -t nat -C ${prerouting_rule} 2>/dev/null || iptables -t nat -A ${prerouting_rule}

      # log all traffic
      prerouting_rule="PREROUTING -i ${intfc} -p ${proto} --dport 53 -j LOG --log-prefix ${LOG_PREFIX}"
      iptables -t nat -C ${prerouting_rule} 2>/dev/null || iptables -t nat -A ${prerouting_rule}

      # perform dnat
      prerouting_rule="PREROUTING -i ${intfc} -p ${proto} --dport 53 -j DNAT --to ${IPV4_IP}:${IPV4_PORT}"
      iptables -t nat -C ${prerouting_rule} 2>/dev/null || iptables -t nat -A ${prerouting_rule}

      # IPv6 force DNS (TCP/UDP 53) through DNS container
      if [ -n "${IPV6_IP}" ]; then
        # source/destination allowlist handling (perhaps this could be 1 rule?)
        prerouting_rule="PREROUTING -i ${intfc} -p ${proto} -s ${IPV6_SOURCE_ALLOWLIST} --dport 53 -j RETURN"
        ip6tables -t nat -C ${prerouting_rule} 2>/dev/null || ip6tables -t nat -A ${prerouting_rule}
        prerouting_rule="PREROUTING -i ${intfc} -p ${proto} -d ${IPV6_DESTINATION_ALLOWLIST} --dport 53 -j RETURN"
        ip6tables -t nat -C ${prerouting_rule} 2>/dev/null || ip6tables -t nat -A ${prerouting_rule}

        # log all traffic
        prerouting_rule="PREROUTING -i ${intfc} -p ${proto} --dport 53 -j LOG --log-prefix ${LOG_PREFIX}"
        ip6tables -t nat -C ${prerouting_rule} 2>/dev/null || ip6tables -t nat -A ${prerouting_rule}

        # perform dnat
        prerouting_rule="PREROUTING -i ${intfc} -p ${proto} --dport 53 -j DNAT --to ${IPV6_IP}:${IPV6_PORT}"
        ip6tables -t nat -C ${prerouting_rule} 2>/dev/null || ip6tables -t nat -A ${prerouting_rule}
      fi
    done
  fi
done
