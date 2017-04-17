
Udp = require 'dgram'

module.exports = class
    
    constructor: (@localAddress, @remoteAddress) ->
        @connectionPool = []

        setInterval ->
            now = Date.now()
            index = 0

            for connect in connectionPool
                break if now - connect.time < 5000
                index += 1

            for i in [0..index - 1]
                connect = connectionPool.shift()
                connect.socket.close()
        , 3000

        @createServer()


    createServer: ->
        receiver = Udp.createSocket 'udp' + @localAddress.type

        receiver.bind @localAddress.port, @localAddress.ip
        receiver.ref()

        receiver.on 'error', console.error

        receive.on 'message', (data, info) =>
            sender = @requestUdpSocket()
            client = info
            
            sender.on 'message', (data, info) ->
                console.log "response #{info.address}:#{info.port}"

                receiver.send data, 0, data.length, client.port, client.address

            console.log "request #{client.address}:#{client.port}"
            sender.send data, 0, data.length, (@requestUdpSocket @remoteAddress.port), @remoteAddress.ip


    requestUdpSocket: ->
        now = Date.now()
        socket = Udp.createSocket 'udp' + @remoteAddress.type

        socket.bind()

        socket.on 'error', console.error
        connectionPool.push {time : now, socket : socket}
        socket


    requestUdpPort: (port) ->
        if port instanceof Array
            port[0] + Math.floor Math.random() * (port[1] - port[0] + 1)
        else
            port

