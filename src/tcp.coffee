
Net = require 'net'

module.exports = class
  
  constructor: (localAddress, remoteAddress) ->
    server = Net.createServer (client) ->
      socket = Net.connect remoteAddress.port, remoteAddress.ip
      client.pipe socket
        .pipe client

      console.info "request #{client.remoteAddress}:#{client.remotePort}"

      client.on 'error', console.error

    server.listen localAddress.port, localAddress.ip
    server.on 'error', console.error

