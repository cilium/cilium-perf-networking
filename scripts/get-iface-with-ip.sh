#!/bin/bash

if [ -z $1 ]; then
    echo 2> "Usage: $0 <ip>"
    exit 1
fi

iface_=$(ip -j addr  | jq ".[] |  {name: .ifname, has_ip:(.addr_info | any(.[] ; .local == \"$1\")) } | select(.has_ip == true) | .name")
eval echo $iface_
