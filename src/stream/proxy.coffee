
Transform = (require 'stream').Transform

pregQuote = (str) -> str.replace /[-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"


module.exports = class extends Transform

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
