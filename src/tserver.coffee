
Net = require 'net'
Event = require 'events'
EncodeStream = require './stream/encode'
DecodeStream = require './stream/decode'

module.exports = class

    constructor: (@localAddress, @remoteAddress, @argv) ->
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

            if @argv.c?
                encoder = new EncodeStream
                decoder = new DecodeStream

                encoder.initCipher @argv.c, @argv.p
                decoder.initDecipher @argv.c, @argv.p
                @sockets[uuid].pipe encoder
                    .pipe @pipes[uuid]
                    .pipe decoder
                    .pipe @sockets[uuid]
            else
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
        
        socket.on 'error', console.error

        @dataEvent.emit 'pipe', uuid


    createRemoteServer: ->
        @remoteServer = Net.createServer (socket) =>
            @accept socket

        @remoteServer.on 'error', console.error
        @remoteServer.listen @remoteAddress.port, @remoteAddress.ip


    createLocalServer: ->
        @localServer = Net.createServer (socket) =>
            connected = no

            socket.on 'error', console.error

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

        @localServer.on 'error', console.error
        @localServer.listen @localAddress.port, @localAddress.ip
    

