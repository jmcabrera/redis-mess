# Purpose

Simulate a Redis cluster and add some network conditions to it

## Setup

### Setup Docker-desktop iptables

```
$ docker run -it --rm --name injector --net=host --cap-add=NET_ADMIN -v $PWD:/app -w /app redis:5.0.6 bash
root@docker-desktop:/app# apt update && apt install -y iptables sudo net-tools
<...>
root@docker-desktop:/app# . ./mess.sh
```

Will create 
* dedicated IPs on the loopback interface
* a bunch of iptables rules and chains
* a bunch of aliases to create network conditions

Keep this terminal opened ==> The Redis Admin

### Start the redis nodes

```
$ cd confs; docker compose up
```

### Form the cluster

```
root@docker-desktop:/app# redis-cli --cluster create \
 127.1.1.1:6379 \
 127.1.2.1:6379 \
 127.1.3.1:6379 \
 127.1.1.2:6379 \
 127.1.2.2:6379 \
 127.1.3.2:6379 \
 --cluster-replicas 1

```
Keep this terminal opened ==> The Redis Admin

### Start injection

```
$ docker run -it --rm --name redis-admin --net=host --cap-add=NET_ADMIN -v $PWD:/app -w /app node bash
root@docker-desktop:/app# node index.js
```

Will start adding a message per second in the redis cluster.

### Sabotage
In the Redis Admin:
```
root@docker-desktop:/app# shut M1
```


