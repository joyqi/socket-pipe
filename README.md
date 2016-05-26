# Socket Pipe

Socket Pipe can forward your socket from one address to anoter without any configs. It supports both tcp and udp, you can simplely make a software net-bridge.

## Install

```
npm install -g socket-pipe
```

## Usage

```
socket-pipe -l 127.0.0.1@53 -r 8.8.8.8@53 -t udp
```

## Example

```
[Client 127.0.0.1:XXXX] <====> [socket-pipe 192.168.1.20:53] <===> ... [socket-pipe] x n ... <===> [Server 8.8.8.8:53]
```
