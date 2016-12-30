
Transform = (require 'stream').Transform
Crypto = require 'crypto'


# 加密流
module.exports = class extends Transform

    initDecipher: (cipher, password) ->
        @decipher = Crypto.createDecipher cipher, password
        @received = no
        @packet = null
        @last = null


    _transform: (buff, enc, callback) ->
        try
            if @last?
                newBuff = new Buffer @last.length + buff.length
                @last.copy newBuff, 0
                buff.copy newBuff, @last.length
                buff = newBuff
                @last = null

            if not @received
                length = buff.readInt32LE 0

                console.info "new packet #{length}"

                @packet = new Buffer length
                @offset = 0

            end = Math.min buff.length - 1, 3 + @packet.length - @offset
            console.info "end with #{end}"

            buff.copy @packet, @offset, 4, end
            @received = not (end <= buff.length - 1)
            @offset += end - 3

            @last = buff.slice end + 1 if end < buff.length - 1
            callback null, @decipher.update @packet if not @received
        catch e
            callback e, null
