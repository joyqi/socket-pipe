
Net = require 'net'
Event = require 'events'
Http = require 'http'
UUID = require 'node-uuid'
Request = require 'request'
Transform = (require 'stream').Transform
Zlib = require 'zlib'

pregQuote = (str) -> str.replace /[-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"

class ProxyStream extends Transform


    setFrom: (from) ->
        @from = new RegExp (pregQuote from), 'ig'


    setTo: (@to) ->


    setStatusCode: (statusCode) ->
        @res.statusCode = statusCode

    
    setHeader: (k, v) ->
        @res.setHeader k, if k == 'location' then (@replace v) else v


    pipe: (@res) ->
        super

    
    replace: (input) ->
        if Buffer.isBuffer input
            str = input.toString 'utf8'
            Buffer.from (@replace str), 'utf8'
        else
            input.replace @from, @to

    
    _transform: (buff, enc, callback) ->
        callback null, buff


module.exports = class

    constructor: (@localAddress, @remoteAddress) ->
        @id = 0
        @dataEvent = new Event
        @daemonSockets = {}
        @sockets = {}
        @pipes = {}

        @dataEvent.on 'pipe', (uuid, hash) =>
            return if not @sockets[uuid]?

            if not @pipes[uuid]?
                buff = new Buffer 4
                buff.writeInt32LE uuid

                return if not @daemonSockets[hash]?
                
                console.info "request pipe #{uuid}"
                return @daemonSockets[hash][0].write buff


            host = if @daemonSockets[hash][1]? then @daemonSockets[hash][1] else @sockets[uuid][0].headers.host
            url = 'http://' + host + @sockets[uuid][0].url
            method = @sockets[uuid][0].method.toLowerCase()
            
            transform = new ProxyStream
            transform.setFrom host
            transform.setTo @sockets[uuid][0].headers.host

            Object.defineProperty transform, 'statusCode', set: transform.setStatusCode

            @sockets[uuid][0]
                .pipe Request[method] url
                .pipe transform
                .pipe @sockets[uuid][1]

            @sockets[uuid][0].resume()
        
        @createLocalServer()
        @createRemoteServer()


    accept: (req, res, hash) ->
        console.info "accept #{req.headers.host}#{req.url}"
        
        uuid = @id
        @id += 1
        @sockets[uuid] = [req, res]

        res.on 'close', =>
            console.info "close socket #{uuid}"
            if @sockets[uuid]?
                delete @sockets[uuid]
        
        @dataEvent.emit 'pipe', uuid, hash


    createRemoteServer: ->
        @remoteServer = Http.createServer (req, res) =>
            [hash] = req.headers.host.split '.'
            console.log hash

            if @daemonSockets[hash]?
                @accept req, res, hash
            else
                res.writeHead 404
                res.end 'Not Found'

        @remoteServer.listen @remoteAddress.port, @remoteAddress.ip


    createLocalServer: ->
        @localServer = Net.createServer (socket) =>
            connected = no

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
                        @pipes[uuid] = socket

                        socket.on 'close', =>
                            console.info "close pipe #{uuid}"

                            if @pipes[uuid]?
                                delete @pipes[uuid]
                        
                        console.info "created pipe #{uuid}"
                        @dataEvent.emit 'pipe', uuid, hash

        @localServer.listen @localAddress.port, @localAddress.ip
    

