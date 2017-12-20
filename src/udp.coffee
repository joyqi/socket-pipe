
Udp = require 'dgram'

module.exports = class
    
    constructor: (@localAddress, @remoteAddress) ->
        @connectionPool = {}

        setInterval =>
            now = Date.now()
            index = 0

            for key, connect of @connectionPool
                if now - connect.time < 5000
                    connect.socket.close()
                    delete @connectionPool[key]
                    console.log "close #{key}"
        , 10000

        @createServer()


    createServer: ->
        receiver = Udp.createSocket 'udp' + @localAddress.type

        receiver.bind @localAddress.port, @localAddress.ip
        receiver.ref()

        receiver.on 'error', console.error

        receiver.on 'message', (data, info) =>
            key = @requestUdpSocket info
            sender = @connectionPool[key].socket
            client = info
            
            sender.on 'message', (data, info) =>
                console.log "response #{info.address}:#{info.port}"
                
                @connectionPool[key].time = Date.now() if typeof @connectionPool[key] != 'undefined'
                receiver.send data, 0, data.length, client.port, client.address

            console.log "request #{client.address}:#{client.port}"
            sender.send data, 0, data.length, (@requestUdpPort @remoteAddress.port), @remoteAddress.ip


    requestUdpSocket: (info) ->
        now = Date.now()
        key = info.address + ':' + info.port

        if typeof @connectionPool[key] != 'undefined'
            @connectionPool[key].time = now
            return key

        socket = Udp.createSocket 'udp' + @remoteAddress.type
        socket.bind()

        socket.on 'error', (err) ->
            console.error err
            socket.close()
            delete @connectionPool[key]

        @connectionPool[key] = {time : now, socket : socket}
        key


    requestUdpPort: (port) ->
        if port instanceof Array
            port[0] + Math.floor Math.random() * (port[1] - port[0] + 1)
        else
            port

