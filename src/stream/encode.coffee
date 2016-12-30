
Transform = (require 'stream').Transform
Crypto = require 'crypto'


# 加密流
module.exports = class extends Transform

    initCipher: (cipher, password) ->
        @cipher = Crypto.createCipher cipher, password


    createPacket: (buff) ->
        packet = new Buffer buff.length + 4
        buff.copy packet, 4, 0, buff.length - 1
        packet.writeInt32LE buff.length, 0

        console.info "enconde #{buff.length}"

        packet

    
    _transform: (buff, enc, callback) ->
        try
            packet = @createPacket @cipher.update buff
            callback null, packet
        catch e
            callback e, null
