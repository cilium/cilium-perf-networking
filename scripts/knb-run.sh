#!/bin/bash

set -e

CMD_PREFIX=""

function dorr() {
    local proto=$1

    # burst=0
    for cli_host_opt in "" "--cli-on-host"; do
        for srv_host_opt in "" "--srv-on-host"; do
            for burst in 0; do
                local label=${proto}_rr_b${burst}
                if [ -n "$cli_host_opt" ]; then
                    label="$label-hostcli"
                fi
                if [ -n "$srv_host_opt" ]; then
                    label="$label-hostsrv"
                fi
                $CMD_PREFIX $xdir/knb pod2pod                               \
                    --duration 120                                          \
                    --run-label $label                                      \
                    $cli_host_opt                                           \
                    $srv_host_opt                                           \
                    --client-affinity host=$cli_node                        \
                    --server-affinity host=$srv_node                        \
                    --benchmark netperf                                     \
                    --netperf-type ${proto}_rr                              \
                    --netperf-args "-D" --netperf-args "10"                 \
                    --netperf-bench-args "-r" --netperf-bench-args "1,1"    \
                    --netperf-bench-args "-b" --netperf-bench-args ${burst} \
                    #
            done
        done
    done


    # burst=1 ....
    for burst in 1 2 4 8 16 32 64 128 256 512; do
        $CMD_PREFIX $xdir/knb pod2pod                               \
            --duration 120                                          \
            --run-label ${proto}_rr_b${burst}                       \
            --client-affinity host=$cli_node                        \
            --server-affinity host=$srv_node                        \
            --benchmark netperf                                     \
            --netperf-type ${proto}_rr                              \
            --netperf-args "-D" --netperf-args "10"                 \
            --netperf-bench-args "-r" --netperf-bench-args "1,1"    \
            --netperf-bench-args "-b" --netperf-bench-args ${burst} \
        #
    done
}

function dostream() {
    local ty=$1

    for cli_host_opt in "" "--cli-on-host"; do
        for srv_host_opt in "" "--srv-on-host"; do
            local label="$ty"
            if [ -n "$cli_host_opt" ]; then
                label="$label-hostcli"
            fi
            if [ -n "$srv_host_opt" ]; then
                label="$label-hostsrv"
            fi

            $CMD_PREFIX $xdir/knb pod2pod                      \
                --duration 300                                 \
                --run-label $label                             \
                $cli_host_opt                                  \
                $srv_host_opt                                  \
                --client-affinity host=$cli_node               \
                --server-affinity host=$srv_node               \
                --benchmark netperf                            \
                --netperf-type $ty                             \
                --netperf-args "-D" --netperf-args "10"        \
            #

            for nstreams in 1 2 4 8 16; do
                $CMD_PREFIX $xdir/knb pod2pod                      \
                    --duration 300                                 \
                    --run-label "duper-$label-n${nstreams}"        \
                    --netperf-nstreams ${nstreams}                  \
                    $cli_host_opt                                  \
                    $srv_host_opt                                  \
                    --client-affinity host=$cli_node               \
                    --server-affinity host=$srv_node               \
                    --benchmark netperf                            \
                    --netperf-type $ty                             \
                    --netperf-args "-D" --netperf-args "10"        \
                #
                done
        done
    done
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
    echo >&2 "Usage: $0 [--{tcp,udp}_stream] [--tcp_maerts] [--{tcp,udp}_rr] [--all] [--nloops n] [--dry-run] <dir>"
    exit 1
fi

xdir=$1
readarray -t nodes < <(kubectl get nodes --no-headers | awk '{ print $1 }')
cli_node=${nodes[0]}
srv_node=${nodes[1]}

$CMD_PREFIX ~/go/bin/kubenetbench init -s $xdir

for _ in $(seq $nloops) ; do

    # Stream
    if [ "$run_tcp_stream" == "1" ]; then
        dostream "tcp_stream"
    fi
    if [ "$run_tcp_maerts" == "1" ]; then
        dostream "tcp_maerts"
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

$CMD_PREFIX ./$xdir/knb "done"
