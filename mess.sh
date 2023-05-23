#!/usr/bin/env bash
declare -A nodes
nodes["M1"]="127.1.1.1"
nodes["S1"]="127.1.1.2"
nodes["M2"]="127.1.2.1"
nodes["S2"]="127.1.2.2"
nodes["M3"]="127.1.3.1"
nodes["S3"]="127.1.3.2"

function log {
    echo $(date +"%Y/%m/%d %X") $@
}

function ashut {
    for node in ${@:-${!nodes[@]}}; do
        log "isolating node $node (admin)"
        sudo iptables -I ISOLATION 1 -p tcp -s ${nodes[$node]} -d 127.1.0.0/16 -j DROP
        sudo iptables -I ISOLATION 1 -p tcp -d ${nodes[$node]} -s 127.1.0.0/16 -j DROP
    done
}

function aopen {
    for node in ${@:-${!nodes[@]}}; do
        log "making node $node reachable (admin)"
        sudo iptables -D ISOLATION -p tcp -s ${nodes[$node]} -d 127.1.0.0/16 -j DROP
        sudo iptables -D ISOLATION -p tcp -d ${nodes[$node]} -s 127.1.0.0/16 -j DROP
    done
}

function uopen {
    for node in ${@:-${!nodes[@]}}; do
        log "making node $node reachable (user)"
        sudo iptables -D ISOLATION -p tcp -s ${nodes[$node]} -d 127.0.0.1 -j DROP
        sudo iptables -D ISOLATION -p tcp -d ${nodes[$node]} -s 127.0.0.1 -j DROP
    done
}

function ushut {
    for node in ${@:-${!nodes[@]}}; do
        log "isolating node $node (user)"
        sudo iptables -I ISOLATION 1 -p tcp -s ${nodes[$node]} -d 127.0.0.1 -j DROP
        sudo iptables -I ISOLATION 1 -p tcp -d ${nodes[$node]} -s 127.0.0.1 -j DROP
    done
}

function shut { ushut $@ ; ashut $@; }
function open { uopen $@ ; aopen $@; }

function setup {
    for ip in "${nodes[@]}"; do sudo ifconfig lo add $ip; done

    sudo iptables -A INPUT -p tcp --dport ssh -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --dport ssh -j ACCEPT

    for i in "${!nodes[@]}"; do state[$i]="opened"; done
    # ISOLATION will host failures.
    sudo iptables -N ISOLATION
    # MONITOR will allow us to see the actual flow of packets (iptables -L MONITOR n -v).
    sudo iptables -N MONITOR
    sudo iptables -A MONITOR -p tcp -s 127.0.0.1 -d 127.1.0.0/16 -j RETURN
    sudo iptables -A MONITOR -p tcp -s 127.1.0.0/16 -d 127.0.0.1 -j RETURN
    for ip in "${nodes[@]}"; do
        for chain in {INPUT,OUTPUT}; do
            sudo iptables -A $chain -p tcp -s $ip -j ISOLATION
            sudo iptables -A $chain -p tcp -d $ip -j ISOLATION
            sudo iptables -A $chain -p tcp -s $ip -j MONITOR
            sudo iptables -A $chain -p tcp -d $ip -j MONITOR
        done
        sudo iptables -A MONITOR -p tcp -s $ip -j RETURN
        sudo iptables -A MONITOR -p tcp -d $ip -j RETURN
    done
}

function clusterUp() {
    redis-cli --cluster create \
        127.1.1.1:6379 \
        127.1.2.1:6379 \
        127.1.3.1:6379 \
        127.1.1.2:6379 \
        127.1.2.2:6379 \
        127.1.3.2:6379 \
        --cluster-replicas 1
}

function tear {
    sudo iptables -F OUTPUT
    sudo iptables -F INPUT
    sudo iptables -F ISOLATION
    sudo iptables -F MONITOR
    sudo iptables -X ISOLATION
    sudo iptables -X MONITOR
    unset nodes

    for ip in "${nodes[@]}"; do sudo ifconfig lo del ${ip}; done
}

function monitor {
    sudo watch -d 'sudo iptables -nvL MONITOR && sudo iptables -nvL ISOLATION'
}

function reset {
    sudo iptables -Z MONITOR
}

export -f ushut uopen ashut aopen shut open
export -f setup tear monitor reset

sudo iptables -nvL MONITOR 1>/dev/null 2>&1 || setup
