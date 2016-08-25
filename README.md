# Socket Pipe

Socket Pipe can forward your socket from one address to anoter without any configs. It supports both tcp and udp, you can simplely make a software net-bridge.

## Install

```
npm install -g socket-pipe
```

## Usage

### Tcp socket forwarding

The following example shows how to map a remote address (ip=192.168.1.100 port=80) to a local address (ip=127.0.0.1 port=80) via tcp tunnel.

```
socket-pipe -l 127.0.0.1@80 -r 192.168.1.100@80 -t tcp
```

### Udp socket forwarding

The following example shows how to map a remote address (ip=8.8.8.8 port=53) to a local address (ip=127.0.0.1 port=53) via udp tunnel.

```
socket-pipe -l 127.0.0.1@53 -r 8.8.8.8@53 -t udp
```

### Tcp reverse tunnel

The following example shows how to map a server from LAN (ip=192.168.1.100 port=80) to internet (ip=123.123.123.123 port=80).

#### Client side (LAN)

```
socket-pipe -l 192.168.1.100@80 -r 123.123.123.123@10080 -t tclient
```

#### Server side (internet)

```
socket-pipe -l 123.123.123.123@10080 -r 123.123.123.123@80 -t tserver
```

### Http reverse tunnel

The following example shows how to map multi http servers from LAN (ip=[192.168.1.100 - 192.168.1.102] port=80) to internet (ip=123.123.123.123 port=80).


#### Client side (LAN)

http1
```
socket-pipe -l 192.168.1.100@80 -r 123.123.123.123@10080 -t hclient -x git.dev.com -s git
```

http2
```
socket-pipe -l 192.168.1.101@80 -r 123.123.123.123@10080 -t hclient -x file.dev.com
```

http3
```
socket-pipe -l 192.168.1.102@80 -r 123.123.123.123@10080 -t hclient -s wiki
```


#### Server side (internet)

```
socket-pipe -l 123.123.123.123@10080 -r 123.123.123.123@80 -t hserver
```

There are two special params.

1. `-x` means socket-pipe will transform:
    1. The `Host` value in http request header.
    2. The host part of 'Location' value in http response header.
2. `-s` means specify a domain prefix. The server side will create a random prefix without specifying.

Now you can visit different backend http server in a LAN from a portal on internet.

For example if domain `*.test.com` is pointing to `123.123.123.123`, the visits to `http://git.test.com/` will be forwarded to `http://192.168.1.100/` with host `git.dev.com` because of the domain prefix `git`.

