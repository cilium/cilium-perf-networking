#!/bin/bash

if [ -z $2 ]; then
    echo 2> "Usage: $0 <ip> <mtu>"
    exit 1
fi

iface_=$(ip -j addr  | jq ".[] |  {name: .ifname, has_ip:(.addr_info | any(.[] ; .local == \"$1\")) } | select(.has_ip == true) | .name")
iface=$(eval echo $iface_)

if [ -z "$iface" ]; then
    echo 2> "Interface not found"
    exit 1
fi

ip link set $iface mtu $2
