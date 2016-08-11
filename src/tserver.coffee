
Net = require 'net'
Event = require 'events'

module.exports = class

    constructor: (@localAddress, @remoteAddress) ->
        @id = 0
        @dataEvent = new Event
        @daemonSocket = null
        @sockets = {}
        @pipes = {}

        @dataEvent.on 'pipe', (uuid) =>
            return if not @sockets[uuid]?

            if not @pipes[uuid]?
                buff = new Buffer 4
                buff.writeInt32LE uuid

                return if not @daemonSocket?
                
                console.info "request pipe #{uuid}"
                return @daemonSocket.write buff

            @sockets[uuid].pipe @pipes[uuid]
                .pipe @sockets[uuid]

            @sockets[uuid].resume()
        
        @createLocalServer()
        @createRemoteServer()


    accept: (socket) ->
        console.info "accept #{socket.remoteAddress}:#{socket.remotePort}"
        socket.pause()
        
        uuid = @id
        @id += 1
        @sockets[uuid] = socket

        socket.on 'close', =>
            console.info "close socket #{uuid}"
            if @sockets[uuid]?
                delete @sockets[uuid]
        
        @dataEvent.emit 'pipe', uuid


    createRemoteServer: ->
        @remoteServer = Net.createServer (socket) =>
            @accept socket

        @remoteServer.listen @remoteAddress.port, @remoteAddress.ip


    createLocalServer: ->
        @localServer = Net.createServer (socket) =>
            connected = no

            socket.on 'data', (data) =>
                if not connected
                    connected = yes

                    if data.length == 1
                        console.info "connected #{socket.remoteAddress}:#{socket.remotePort}"
                        @daemonSocket = socket
                    else if data.length == 4
                        uuid = data.readInt32LE 0
                        @pipes[uuid] = socket

                        socket.on 'close', =>
                            console.info "close pipe #{uuid}"

                            if @pipes[uuid]?
                                delete @pipes[uuid]
                        
                        console.info "created pipe #{uuid}"
                        @dataEvent.emit 'pipe', uuid

        @localServer.listen @localAddress.port, @localAddress.ip
    

