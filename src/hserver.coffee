
Net = require 'net'
Event = require 'events'
Http = require 'http'
UUID = require 'node-uuid'
Request = require 'request'
Transform = (require 'stream').Transform
Zlib = require 'zlib'

pregQuote = (str) -> str.replace /[-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"

endSocket = (socket) ->
    socket.resume()
    socket.end "HTTP/1.1 404 Not Found\r\nContent-Type: text/html;charset=UTF-8\r\n\r\nNotFound"

class ProxyStream extends Transform

    constructor: ->
        @filtered = no
        @piped = no
        @buffers = []
        super


    setCallback: (@cb) ->


    setFrom: (from) ->
        @from = new RegExp (pregQuote from), 'ig'


    setTo: (@to) ->


    pipe: (@stream) ->
        @piped = yes
        return super


    release: ->
        if @stream?
            while buffer = @buffers.shift()
                @stream.write buffer


    callback: (err, buff) ->
        if @piped
            super
        else
            @buffers.push buff


    _transform: (buff, enc, callback) ->
        if not @filtered
            str = if enc is 'buffer' then (buff.toString 'binary') else buff
            pos = str.indexOf "\r\n\r\n"

            if pos >= 0
                @filtered = yes

                head = str.substring 0, pos
                body = str.substring pos
            else
                head = str
                body = ''

            if @from? and @to?
                head = head.replace @from, @to

            if matches = head.match /host:\s*([^\r]+)/i
                head = @cb matches[1], head if @cb?

            callback null, Buffer.from head + body, 'binary'

        else
            callback null, buff

        @clear() if (buff.indexOf -1) >= 0


    clear: ->
        @filtered = no
        @buffers = []


module.exports = class

    constructor: (@localAddress, @remoteAddress) ->
        @id = 0
        @dataEvent = new Event
        @daemonSockets = {}
        @sockets = {}
        @pipes = {}

        @dataEvent.on 'accept', (uuid) =>
            return if not @sockets[uuid]?

            input = new ProxyStream
            @sockets[uuid].push input

            input.setCallback (reqHost, head) =>
                console.info "request #{reqHost}"

                [hash] = reqHost.split '.'
                if not @daemonSockets[hash]?
                    return endSocket @sockets[uuid][0]

                host = if @daemonSockets[hash][1]? then @daemonSockets[hash][1] else reqHost
                buff = new Buffer 4
                buff.writeInt32LE uuid

                console.info "request pipe #{uuid}"
                @daemonSockets[hash][0].write buff

                setTimeout =>
                    if not @pipes[uuid]? and @sockets[uuid]? and @daemonSockets[hash]?
                        @daemonSockets[hash][0].write buff
                        console.info "retry pipe #{uuid}"
                , 2000

                regex = new RegExp (pregQuote reqHost), 'ig'

                output = new ProxyStream
                output.setFrom host
                output.setTo reqHost

                @sockets[uuid].push output
                @sockets[uuid][0].pause()

                head.replace regex, host

            @sockets[uuid][0].pipe input
            @sockets[uuid][0].resume()

        @dataEvent.on 'pipe', (uuid, hash) =>
            return if not @sockets[uuid]
            return endSocket @sockets[uuid] if not @daemonSockets[hash]
            return endSocket @sockets[uuid] if not @pipes[uuid]

            @sockets[uuid][1].pipe @pipes[uuid]
                .pipe @sockets[uuid][2]
                .pipe @sockets[uuid][0]

            @sockets[uuid][1].release()
            @sockets[uuid][0].resume()
        
        @createLocalServer()
        @createRemoteServer()


    accept: (socket) ->
        console.info "accept #{socket.remoteAddress}:#{socket.remotePort}"
        
        uuid = @id
        @id += 1

        socket.pause()
        @sockets[uuid] = [socket]

        socket.on 'close', =>
            console.info "close socket #{uuid}"
            if @sockets[uuid]?
                delete @sockets[uuid]

        socket.on 'error', console.error
        
        @dataEvent.emit 'accept', uuid


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
                    op = data.readInt8 0

                    if op == 1
                        parts = (data.slice 1).toString()
                        [transfer, hash] = parts.split '|'
                        hash = UUID.v1() if hash.length == 0 or @daemonSockets[hash]?
                        transfer = null if transfer.length == 0
                        console.info "connected #{socket.remoteAddress}:#{socket.remotePort} = #{hash} #{transfer}"
                        @daemonSockets[hash] = [socket, transfer]

                        socket.on 'close', =>
                            delete @daemonSockets[hash] if hash? and @daemonSockets[hash]?

                        socket.write new Buffer hash
                    else if op == 2
                        uuid = data.readInt32LE 1
                        hash = (data.slice 5).toString()

                        return socket.end() if @pipes[uuid]?

                        @pipes[uuid] = socket

                        socket.on 'close', =>
                            console.info "close pipe #{uuid}"

                            if @pipes[uuid]?
                                delete @pipes[uuid]
                        
                        console.info "created pipe #{uuid}"
                        @dataEvent.emit 'pipe', uuid, hash

        @localServer.on 'error', console.error
        @localServer.listen @localAddress.port, @localAddress.ip
    

