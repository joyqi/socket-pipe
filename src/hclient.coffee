
Net = require 'net'
TClient = require './tclient'

module.exports = class extends TClient

    constructor: (@localAddress, @remoteAddress, argv) ->
        @transfer = argv.x
        @specify = argv.s
        @createDaemonSocket()
        @hash = null
        @token = null
 
    # 创建一个常驻的隧道
    createDaemonSocket: ->
        ping = Buffer.from [0]

        @transfer = '' if not @transfer?
        @specify = '' if not @specify?
        parts = @transfer + '|' + @specify + (if @token? then '|' + @token else '')

        tmp = new Buffer parts
        first = new Buffer 1 + tmp.length
        first.writeInt8 1, 0
        tmp.copy first, 1

        @daemonSocket = @connectRemote =>
            connected = no

            @daemonSocket.ref()

            # 创建一个隧道
            @daemonSocket.on 'data', (data) =>
                if not connected
                    connected = yes
                    url = data.toString 'utf8'
                    console.info "url #{url}"

                    [hash, @token] = url.split '|'
                    @hash = Buffer.from hash
                else if data.length == 4
                    uuid = data.readInt32LE 0
                    
                    console.info "request pipe #{uuid}"
                    @createTunnel uuid
            
            # 发送一个ping
            @daemonSocket.write first
            
            setInterval =>
                @daemonSocket.write ping
            , 10000
                
        @daemonSocket.on 'error', console.error

        # 尝试重连
        @daemonSocket.on 'close', =>
            setTimeout =>
                @createDaemonSocket()
            , 1000


    # 创建隧道
    createTunnel: (uuid) ->
        ping = new Buffer 5 + @hash.length
        ping.writeInt8 2, 0
        ping.writeInt32LE uuid, 1
        @hash.copy ping, 5
        
        socket = @connectRemote =>
            console.info "connect remote #{uuid}"

            local = @connectLocal ->
                console.info "connect local #{uuid}"
                
                socket.write ping
                socket.pipe local
                    .pipe socket
                
                console.info "piped #{uuid}"

