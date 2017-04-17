
Net = require 'net'
EncodeStream = require './stream/encode'
DecodeStream = require './stream/decode'

module.exports = class
    
    constructor: (@localAddress, @remoteAddress, @argv) ->
        @createDaemonSocket()


    # 创建一个常驻的隧道
    createDaemonSocket: ->
        ping = Buffer.from [0]

        @daemonSocket = @connectRemote =>
            @daemonSocket.ref()

            # 创建一个隧道
            @daemonSocket.on 'data', (data) =>
                if data.length == 4
                    uuid = data.readInt32LE 0
                    
                    console.info "request pipe #{uuid}"
                    @createTunnel uuid
            
            # 发送一个ping
            @daemonSocket.write ping
            
            setInterval =>
                @daemonSocket.write ping
            , 10000
                
        # 尝试重连
        @daemonSocket.on 'close', =>
            setTimeout =>
                @createDaemonSocket()
            , 1000


    # 连接远程
    connectRemote: (cb) ->
        socket = Net.connect @remoteAddress.port, @remoteAddress.ip, cb

        socket.on 'error', console.error

        socket


    # 连接本地
    connectLocal: (cb) ->
        socket = Net.connect @localAddress.port, @localAddress.ip, cb

        socket.on 'error', console.error

        socket


    # 创建隧道
    createTunnel: (uuid) ->
        ping = new Buffer 4
        ping.writeInt32LE uuid, 0
        
        socket = @connectRemote =>
            console.info "connect remote #{uuid}"

            local = @connectLocal =>
                console.info "connect local #{uuid}"
                
                socket.write ping
        
                if @argv.c?
                    encoder = new EncodeStream
                    decoder = new DecodeStream

                    encoder.initCipher @argv.c, @argv.p
                    decoder.initDecipher @argv.c, @argv.p

                    socket.pipe decoder
                        .pipe local
                        .pipe encoder
                        .pipe socket
                else
                    socket.pipe local
                        .pipe socket
                
                console.info "piped #{uuid}"

