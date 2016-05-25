
var Opt = require('optimist'),
    Net = require('net');


var argv = Opt
    .usage('Usage: $0 [ -p 80 ] [ -t 10.0.10.11:80 ]')
    .demand(['p', 't'])
    .boolean('h')
    .alias('h', 'help')
    .describe('p', 'Local port.')
    .describe('t', 'Remote address.')
    .argv;

if (argv.h) {
    Opt.showHelp();
    process.exit(0);
}

var parsed = argv.t.split(':'),
    host = parsed[0],
    port = parsed.length > 1 ? parsed[1] : argv.p;

var server = Net.Server(function (client) {
    var socket = Net.connect(port, host);
    client.pipe(socket).pipe(client);
    
    console.log("Connecting " + client.remoteAddress 
        + ":" + client.remotePort);
});

server.listen(argv.p);
console.log("Listening at port " + argv.p);

