#!/bin/bash

METRICS="THROUGHPUT,THROUGHPUT_UNITS,THROUGHPUT_CONFID,LOCAL_SEND_SIZE,LOCAL_RECV_SIZE,REMOTE_SEND_SIZE,REMOTE_RECV_SIZE,PROTOCOL,LOCAL_SEND_CALLS,LOCAL_BYTES_PER_SEND,LOCAL_RECV_CALLS,LOCAL_BYTES_PER_RECV,REMOTE_SEND_CALLS,REMOTE_BYTES_PER_SEND,REMOTE_RECV_CALLS,REMOTE_BYTES_PER_RECV,LOCAL_SEND_THROUGHPUT,LOCAL_RECV_THROUGHPUT,REMOTE_SEND_THROUGHPUT,REMOTE_RECV_THROUGHPUT,LOCAL_SYSNAME,LOCAL_RELEASE,LOCAL_VERSION,LOCAL_MACHINE,REMOTEL_SYSNAME,REMOTEL_RELEASE,REMOTEL_VERSION,REMOTEL_MACHINE,COMMAND_LINE,LOCAL_TRANSPORT_RETRANS,REMOTE_TRANSPORT_RETRANS"

RR_METRICS="TRANSACTION_RATE,P50_LATENCY,P90_LATENCY,RT_LATENCY,MEAN_LATENCY,STDEV_LATENCY,REQUEST_SIZE,RESPONSE_SIZE"

set -e

function run_duper_netperf() {
    loops=$1
    shift
    echo "DUPER_NETPERF: NSTREAMS=$loops ARGS=$@"
    for ((i=0; i<loops; i++)); do
        prefix="$(printf "%02d" $i) "
        (netperf -s 2 "$@" | sed -e "s/^/$prefix/") &
    done
    wait
}

function duper_netperf() {
    run_duper_netperf "$@" | perl -ln -e 'BEGIN { $sum = 0; $count = 0 } END { print "NSTREAMS=$count\nAGGREGATE_THROUGHPUT=$sum"; } if (/ THROUGHPUT=(\S+)$/) { $sum += $1; $count += 1 } print;'
}

function dorr() {
    local proto=$1

    for b in 0 1 2 4 8 16 32 64 128 256 512; do
        cmd="$CMD_PREFIX netperf    \
            -t ${proto}_rr          \
            -l 120                  \
            -D 10                   \
            -H $rhost               \
            -j                      \
            --                      \
            -P  ,8000               \
            -k $METRICS,$RR_METRICS \
            -r 1,1                  \
            -b $b"

        echo $cmd
        $cmd
        echo "END"
    done
}

function dostream_duper() {
    local ty=$1
    for nstreams in 1 2 4 8 16; do
        cmd="duper_netperf $nstreams  \
            $CMD_PREFIX netperf       \
            -H $rhost                 \
            -D 10                     \
            -l 300                    \
            -t $ty                    \
            -j                        \
            --                        \
            -P ,8000                  \
            -k $METRICS"

        echo $cmd
        $cmd
        echo "END"
    done
}

function dostream() {
    local ty=$1
    cmd="$CMD_PREFIX netperf  \
        -H $rhost             \
        -D 10                 \
        -l 300                \
        -t $ty                \
        -j                    \
        --                    \
        -P ,8000              \
        -k $METRICS"

    echo $cmd
    $cmd
    echo "END"
}

nloops=2

while true; do
    case $1 in
        --tcp_stream)
            run_tcp_stream=1
            ;;

        --tcp_maerts)
            run_tcp_maerts=1
            ;;

        --tcp_rr)
            run_tcp_rr=1
            ;;

        #--tcp_crr)
        #    run_tcp_crr=1
        #    ;;

        --udp_stream)
            run_udp_stream=1
            ;;

        --udp_rr)
            run_udp_rr=1
            ;;

        --all)
            run_tcp_stream=1
            run_tcp_maerts=1
            run_udp_stream=1
            run_tcp_rr=1
            run_udp_rr=1
            run_tcp_crr=1
            ;;

        --dry-run)
            CMD_PREFIX="echo"
            ;;

        --nloops)
            if [ "$2" ]; then
                nloops=$2
                shift
            else
                echo >2 "--nloops requires argument"
                exit 1
            fi
            ;;

        -?*)
              echo 'WARN: Unknown option (ignored): %s' "$1" >&2
              ;;

        --)
            shift
            break
            ;;

        *)
            break
    esac
    shift
done

if [ -z "$1" ]; then
    echo "Usage: $0 [--{tcp,udp}_stream] [--tcp_maerts] [--{tcp,udp}_rr] [--all] [--nloops n] <rhost>"
    exit 1
fi

rhost=$1

for _ in $(seq $nloops) ; do

    # Stream
    if [ "$run_tcp_stream" == "1" ]; then
        dostream "tcp_stream"
        dostream_duper "tcp_stream"
    fi
    if [ "$run_tcp_maerts" == "1" ]; then
        dostream "tcp_maerts"
        dostream_duper "tcp_maerts"
    fi
    if [ "$run_udp_stream" == "1" ]; then
        dostream "udp_stream"
    fi

    # RR
    if [ "$run_tcp_rr" == "1" ]; then
        dorr "tcp"
    fi

    if [ "$run_udp_rr" == "1" ]; then
        dorr "udp"
    fi
done
