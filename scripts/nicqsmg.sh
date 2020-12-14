#!/bin/bash
#
# script for managing NIC queues on Linux. This is mostly designed for the
# ixgbe driver. There are some parts that work for the sfc driver, but not all
# of them.
#
# Kornilios Kourtis <akourtis@inf.ethz.ch>

#set -x
set -e

############################################
## RX

function xdo() {
	cmd=$*
	echo " " $cmd
	eval $cmd
}

function check_rps_qs() {
	f0="/sys/class/net/$iface/queues/rx-0/rps_cpus"
	if [ ! -f  $f0 ]; then
		echo "$f0 does not exist: bailing out"
		exit 1
	fi
}

function max_rxq() {
	maxq=0
	for f in /sys/class/net/$iface/queues/rx-*/rps_cpus; do
	    q=$(echo $f | sed -e 's/.*rx-\([[:digit:]]\+\).*/\1/')
	    if [ $q -gt $maxq ]; then
	        maxq=$q
	    fi
	done
	echo $maxq
}


function rps_rr() {

	check_rps_qs
	maxq=$(max_rxq)

	nqueues=$((maxq+1))
	qentries=$(( $rps_entries / $nqueues ))

	xdo $(printf "echo %s > %s\n" $rps_entries "/proc/sys/net/core/rps_sock_flow_entries")
	for q in $(seq 0 $maxq); do
	    c=$(( $q % $ncpus))
	    f="/sys/class/net/$iface/queues/rx-$q/rps_cpus"
	    echo "# Assigning RX Queue $q to cpu $c"
	    xdo $(printf "echo %x > %s\n" $(( 1<<$c )) $f)
	    xdo "echo $qentries > /sys/class/net/$iface/queues/rx-$q/rps_flow_cnt"
	done
	echo
}

function rps_reset() {

	check_rps_qs
	maxq=$(max_rxq)

	nqueues=$((maxq+1))
	qentries=$(( $rps_entries / $nqueues ))

	xdo "echo 0 > /proc/sys/net/core/rps_sock_flow_entries"
	for q in $(seq 0 $maxq); do
	    c=$(( $q % $ncpus))
	    f="/sys/class/net/$iface/queues/rx-$q/rps_cpus"
	    xdo "echo 0 > $f"
	    xdo "echo 0 > /sys/class/net/$iface/queues/rx-$q/rps_flow_cnt"
	done
	echo
}

function rps_pr() {
	check_rps_qs
	maxq=$(max_rxq)

	nqueues=$((maxq+1))
	qentries=$(( $rps_entries / $nqueues ))

	echo "/sys/class/net/$iface/queues/rx-XX/rps_cpus:"
	for q in $(seq 0 $maxq); do
		c=$(( $q % $ncpus))
		f="/sys/class/net/$iface/queues/rx-$q/rps_cpus"
		printf "%7s :: %s\n" "rx-$q" $(cat $f)
	done
}

############################################
## TX

function check_xps_qs() {
	f0="/sys/class/net/$iface/queues/tx-0/xps_cpus"
	if [ ! -f  $f0 ]; then
		echo "$f0 does not exist: bailing out"
		exit 1
	fi
}

function max_txq() {
	maxq=0
	for f in /sys/class/net/$iface/queues/tx-*/xps_cpus; do
	    q=$(echo $f | sed -e 's/.*tx-\([[:digit:]]\+\).*/\1/')
	    if [ $q -gt $maxq ]; then
	        maxq=$q
	    fi
	done
	echo $maxq
}

function xps_rr() {

	check_xps_qs
	maxq=$(max_txq)

	nqueues=$((maxq+1))
	for q in $(seq 0 $maxq); do
	    c=$(( $q % $ncpus))
	    f="/sys/class/net/$iface/queues/tx-$q/xps_cpus"
	    echo "# Assigning TX Queue $q to cpu $c"
	    xdo $(printf "echo %x > %s\n" $(( 1<<$c )) $f)
	done
	echo
}

function xps_reset() {

	check_xps_qs
	maxq=$(max_txq)

	nqueues=$((maxq+1))
	for q in $(seq 0 $maxq); do
	    c=$(( $q % $ncpus))
	    f="/sys/class/net/$iface/queues/tx-$q/xps_cpus"
	    xdo "echo 0 > $f"
	done
	echo
}

function xps_pr() {
	check_xps_qs
	maxq=$(max_txq)

	nqueues=$((maxq+1))
	qentries=$(( $rps_entries / $nqueues ))

	echo "/sys/class/net/$iface/queues/tx-XX/xps_cpus:"
	for q in $(seq 0 $maxq); do
		c=$(( $q % $ncpus))
		f="/sys/class/net/$iface/queues/tx-$q/xps_cpus"
		printf "%7s :: %s\n" "tx-$q" $(cat $f)
	done
}

############################################
## Flows

function flows_reset() {
	 for fid  in $(/sbin/ethtool -n $iface | sed -n 's/Filter: \([[:digit:]]\+\)/\1/p')
	 do
		xdo "/sbin/ethtool -N $iface delete $fid"
	 done
}

function flows_print() {
	 ethtool -n $iface
}

function udp_flows_src_port() {
	srcp0=$1
	nqs=$2
	q0=0;

	xdo "/sbin/ethtool -K $iface ntuple on"
	echo $(($q0 + $nqs - 1))
	for i in $(seq 0 $(($nqs - 1)))
	do
		q=$(( $q0 + $i))
		srcp=$(( $srcp0 + $i))
		xdo "/sbin/ethtool -N $iface flow-type udp4 src-port $srcp action $q"
	done
}

function udp_flows_src_port_full() {
	srcp0=$1
	nqs=$2
	src_ip=$3
	dst_ip=$4
	dstp=$5
	q0=0;

	xdo "/sbin/ethtool -K $iface ntuple on"
	echo $(($q0 + $nqs - 1))
	for i in $(seq 0 $(($nqs - 1)))
	do
		q=$(( $q0 + $i))
		srcp=$(( $srcp0 + $i))
		xdo "/sbin/ethtool -N $iface flow-type udp4 src-port $srcp src-ip $src_ip dst-port $dstp dst-ip $dst_ip action $q"
	done
}

function udp_flows_dst_port() {
	dstp0=$1
	nqs=$2
	q0=0;

	xdo "/sbin/ethtool -K $iface ntuple on"
	echo $(($q0 + $nqs - 1))
	for i in $(seq 0 $(($nqs - 1)))
	do
		q=$(( $q0 + $i))
		dstp=$(( $dstp0 + $i))
		xdo "/sbin/ethtool -N $iface flow-type udp4 dst-port $dstp action $q"
	done
}

function udp_flows_dst_port_full() {
	dstp0=$1
	nqs=$2
	src_ip=$3
	dst_ip=$4
	srcp=$5
	q0=0;

	xdo "/sbin/ethtool -K $iface ntuple on"
	echo $(($q0 + $nqs - 1))
	for i in $(seq 0 $(($nqs - 1)))
	do
		q=$(( $q0 + $i))
		dstp=$(( $dstp0 + $i))
		xdo "/sbin/ethtool -N $iface flow-type udp4 dst-port $dstp src-ip $src_ip dst-ip $dst_ip src-port $srcp action $q"
	done
}

function udp_flows_src_port_rr() {
	srcp0=$1
	nqs=$2
	nfilters=$3
	q0=0;

	xdo "/sbin/ethtool -K $iface ntuple on"
	echo $(($q0 + $nqs - 1))
	for i in $(seq 0 $(($nfilters - 1)))
	do
		q=$(( ($q0 + $i) % $nqs ))
		srcp=$(( $srcp0 + $i))
		xdo "/sbin/ethtool -N $iface flow-type udp4 src-port $srcp action $q"
	done
}

function eth_irqs() {

	case $driver in
        ixgbe)
		x="$iface-TxRx-(\d+)"
		;;
	i40e)
		x="i40e-$iface-TxRx-(\d+)"
		;;

    ice)
		x="ice-$iface-TxRx-(\d+)"
        ;;

	sfc)
		x="$iface-(\d+)"
		;;

	virtio_net)
		for devpath in /sys/module/virtio_net/drivers/virtio:virtio_net/virtio*; do
			if [ -d $devpath/net/$iface ]; then
				virtio_dev=$(basename $devpath)
			fi
		done
		if [ -z "$virtio_dev" ]; then
			echo "Cannot locate virtio device for interface $iface"
			exit 1
		fi
		x="$virtio_dev-(?:input|output).(\d+)"
		;;
	*)
		echo "Unknown driver: $driver. Baling out." 1>&2
		exit 1 ;;
	esac

	perl -ne "if (/^([^:]+):.*($x)/) { print \"\$1 \$2 \$3\n\"; }" /proc/interrupts
}

function eth_irq_cpus_rr() {
    eth_irqs | while read irq qname q;
    do
        echo "# affining irq $irq to core $q ($qname)"
        xdo "echo $q > /proc/irq/$irq/smp_affinity_list"
    done
}

function eth_irq_pr() {
    eth_irqs |  while read irq qname q;
    do
        printf "irq:%-3s dev:%-20s affinity:%3d\n" $irq $qname $(cat /proc/irq/$irq/smp_affinity_list)
    done
}

if [ -z "$2" ]; then
    echo "Usage: $0 [iface] [commands...]"
    echo "Commands: rps_rr"
    echo "          xps_rr"
    echo "          rps_pr"
    echo "          xps_pr"
    echo "          rps_reset"
    echo "          xps_reset"
    echo "          fl_reset"
    echo "          udpfl_srcp <src_port0> <nqueues>"
    echo "          udpfl_dstp <dst_port0> <nqueues>"
    echo "          udpfl_srcp_rr <src_port0> <nqueues> <nfilters>"
    echo "          rps_pr"
    echo "          xps_pr"
    echo "          irq_rr"
    echo "          irq_pr"
    exit 1
fi

iface=$1
shift

driver=$(/sbin/ethtool -i $iface | perl -n -e 'print "$1" if /driver: (\S+)$/')

ncpus=$(nproc)
rps_entries=32768

while [ "$#" -ne 0 ]
do
	cmd=$1
	shift
	case $cmd in

		rps_rr) rps_rr;;
		rps_pr) rps_pr;;
		rps_reset) rps_reset;;
		xps_rr) xps_rr;;
		xps_pr) xps_pr;;
		xps_reset) xps_reset;;

		fl_reset) flows_reset;;
		fl_pr) flows_print;;

		udpfl_srcp)
			if [ -z "$2" ]; then
				echo: "udpfl_srcp <src_port0> <nqueues>"
				exit 1
			fi;
			udp_flows_src_port $1 $2;
			shift 2
			;;

		# UNTESTED
		udpfl_srcp_full)
			if [ -z "$5" ]; then
				echo: "udpfl_srcp <src_port0> <nqueues> <src_ip> <dst_ip> <dst_port>"
				exit 1
			fi;
			udp_flows_src_port_full $1 $2 $3 $4 $5;
			shift 5
			;;

		udpfl_dstp)
			if [ -z "$2" ]; then
				echo: "udpfl_dstp <dst_port0> <nqueues>"
				exit 1
			fi;
			udp_flows_dst_port $1 $2;
			shift 2
			;;

		# UNTESTED
		udpfl_dstp_full)
			if [ -z "$5" ]; then
				echo: "udpfl_dstp <dst_port0> <nqueues> <src_ip> <dst_ip> <src_port>"
				exit 1
			fi;
			udp_flows_dst_port_full $1 $2 $3 $4 $5;
			shift 5
			;;

		udpfl_srcp_rr)
			if [ -z "$3" ]; then
				echo: "udpfl_srcp_rr <src_port0> <nqueues> <nfilters>"
				exit 1
			fi;
			udp_flows_src_port_rr $1 $2 $3;
			shift 3
			;;

                irq_rr)  eth_irq_cpus_rr;;
                irq_pr)  eth_irq_pr;;

		*)
			echo "Unknown command: $cmd"; exit 1;;
	esac
done

