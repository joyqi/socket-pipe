
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

var localParsed = (argv.p + '').split(':'),
    targetParsed = (argv.t + '').split(':'),
    localPort = localParsed[localParsed.length - 1],
    localHost = localParsed.length > 1 ? localParsed[0] : '0.0.0.0',
    targetHost = targetParsed[0],
    targetPort = targetParsed.length > 1 ? targetParsed[1] : argv.p;

var server = Net.Server(function (client) {
    var socket = Net.connect(targetPort, targetHost);
    client.pipe(socket).pipe(client);
    
    console.log("Connecting " + client.remoteAddress 
        + ":" + client.remotePort);

    client.on('error', function (err) {
        console.log("Error " + err);
    });
});

server.listen(localPort, localHost);
console.log("Listening at " + argv.p);

server.on('error', function (err) {
    console.log("Error " + err);
});

