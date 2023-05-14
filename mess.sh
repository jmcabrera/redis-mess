#!/usr/bin/env bash
export subnets=([0]=172.31.1.0/24 [1]=172.31.2.0/24 [2]=172.31.3.0/24)

function log {
    echo $(date +"%Y/%m/%d %X") $@
}

function status {
    for i in "${!state[@]}"; do
        log "node $i    -> ${state[$i]}"
    done
}

function shut {
    for i in ${@:-0 1 2}; do
        log "isolating node $i"
        #        sudo iptables -I ISOLATION 1 -d ${subnets[$i]} -j DROP
        sudo iptables -I ISOLATION 1 -s ${subnets[$i]} -j DROP
        state[$i]="shut down"
    done
}

function open {
    for i in ${@:-0 1 2}; do
        log "making node $i reachable"
        #        sudo iptables -D ISOLATION -d ${subnets[$i]} -j DROP
        sudo iptables -D ISOLATION -s ${subnets[$i]} -j DROP
        state[$i]="opened"
    done
}

function setup {
    unset state

    sudo iptables -A INPUT -p tcp --dport ssh -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --dport ssh -j ACCEPT
    sudo iptables -A INPUT -s 88.136.162.240/32 -j ACCEPT
    sudo iptables -A INPUT -d 88.136.162.240/32 -j ACCEPT
    sudo iptables -A OUTPUT -s 88.136.162.240/32 -j ACCEPT
    sudo iptables -A OUTPUT -d 88.136.162.240/32 -j ACCEPT

    for i in "${!subnets[@]}"; do state[$i]="opened"; done
    # ISOLATION will host failures.
    sudo iptables -N ISOLATION
    # MONITOR will allow us to see the actual flow of packets (iptables -L MONITOR n -v).
    sudo iptables -N MONITOR
    for i in "${!subnets[@]}"; do
        sudo iptables -A INPUT -s ${subnets[$i]} -j ISOLATION
        sudo iptables -A INPUT -d ${subnets[$i]} -j ISOLATION
        sudo iptables -A OUTPUT -s ${subnets[$i]} -j ISOLATION
        sudo iptables -A OUTPUT -d ${subnets[$i]} -j ISOLATION
        sudo iptables -A INPUT -s ${subnets[$i]} -j MONITOR
        sudo iptables -A INPUT -d ${subnets[$i]} -j MONITOR
        sudo iptables -A OUTPUT -s ${subnets[$i]} -j MONITOR
        sudo iptables -A OUTPUT -d ${subnets[$i]} -j MONITOR
        sudo iptables -A MONITOR -s ${subnets[$i]} -j RETURN
        sudo iptables -A MONITOR -d ${subnets[$i]} -j RETURN
    done
}

function tear {
    sudo iptables -F OUTPUT
    sudo iptables -F INPUT
    sudo iptables -F ISOLATION
    sudo iptables -F MONITOR
    sudo iptables -X ISOLATION
    sudo iptables -X MONITOR
}

function monitor {
    sudo watch -d 'sudo iptables -nvL MONITOR && sudo iptables -nvL ISOLATION'
}

function reset {
    sudo iptables -Z MONITOR
}

export -f status shut open
export -f setup tear monitor reset

sudo iptables -nvL MONITOR 1>/dev/null 2>&1 || setup
