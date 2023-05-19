#!/usr/bin/env bash
declare -A nodes
nodes["M1"]="6370 16370"
nodes["M2"]="6380 16380"
nodes["M3"]="6390 16390"
nodes["S1"]="6371 16371"
nodes["S2"]="6381 16381"
nodes["S3"]="6391 16391"

declare -A state

function log {
    echo $(date +"%Y/%m/%d %X") $@
}

function status {
    for i in "${!state[@]}"; do
        log "node $i\t-> ${state[$i]}"
    done
}

function _shut {
    portIndex=$1
    shift
    for i in ${@:-${!nodes[@]}}; do
        log "isolating node $i"
        ports=(${nodes[$i]})
        sudo iptables -I ISOLATION 1 -p tcp --sport ${ports[$portIndex]} -j DROP
        sudo iptables -I ISOLATION 1 -p tcp --dport ${ports[$portIndex]} -j DROP
        state[$i]="shut down"
    done
}

function ushut {
    _shut 0 $@ 
}

function ashut {
    _shut 1 $@ 
}

function shut {
    ushut $@
    ashut $@
}

function _open {
    portIndex=$1
    shift
    for i in ${@:-${!nodes[@]}}; do
        ports=(${nodes[$i]})
        log "making node $i reachable"
        sudo iptables -D ISOLATION -p tcp --sport ${ports[$portIndex]} -j DROP
        sudo iptables -D ISOLATION -p tcp --dport ${ports[$portIndex]} -j DROP
        state[$i]="opened"
    done
}

function uopen {
    _open 0 $@ 
}

function aopen {
    _open 1 $@ 
}

function open {
    uopen $@
    aopen $@
}

function setup {
    unset state

    sudo iptables -A INPUT -p tcp --dport ssh -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --dport ssh -j ACCEPT

    for i in "${!nodes[@]}"; do state[$i]="opened"; done
    # ISOLATION will host failures.
    sudo iptables -N ISOLATION
    # MONITOR will allow us to see the actual flow of packets (iptables -L MONITOR n -v).
    sudo iptables -N MONITOR
    for i in "${!nodes[@]}"; do
        for port in ${nodes[$i]}; do
            for chain in {INPUT,OUTPUT}; do
                sudo iptables -A $chain -p tcp --sport $port -j ISOLATION
                sudo iptables -A $chain -p tcp --dport $port -j ISOLATION
                sudo iptables -A $chain -p tcp --sport $port -j MONITOR
                sudo iptables -A $chain -p tcp --dport $port -j MONITOR
            done
            sudo iptables -A MONITOR -p tcp --sport $port -j RETURN
            sudo iptables -A MONITOR -p tcp --dport $port -j RETURN
        done
    done
}

function tear {
    sudo iptables -F OUTPUT
    sudo iptables -F INPUT
    sudo iptables -F ISOLATION
    sudo iptables -F MONITOR
    sudo iptables -X ISOLATION
    sudo iptables -X MONITOR
    unset state nodes
}

function monitor {
    sudo watch -d 'sudo iptables -nvL MONITOR && sudo iptables -nvL ISOLATION'
}

function reset {
    sudo iptables -Z MONITOR
}

export -f status ushut uopen ashut aopen
export -f setup tear monitor reset

sudo iptables -nvL MONITOR 1>/dev/null 2>&1 || setup
