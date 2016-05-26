# Socket Pipe

Socket Pipe can forward your socket from one address to anoter without any configs. It supports both tcp and udp, you can simplely make a software net-bridge.

## Install

```
npm install -g socket-pipe
```

## Usage

```
socket-pipe -l 127.0.0.1@53 -h 8.8.8.8@53 -t udp
```

## Example

```

+-------+
|
|client
|127.0.0.1



```
