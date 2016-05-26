
var Opt = require('optimist'),
    Net = require('net'),
    Udp = require('dgram');


var argv = Opt
    .usage('Usage: $0 [ -l 80 ] [ -r 10.0.10.11:80 ] [ -t udp ]')
    .demand(['l', 'r'])
    .boolean('h')
    .alias('t', 'type')
    .alias('h', 'help')
    .alias('l', 'local')
    .alias('r', 'remote')
    .default('t', 'tcp')
    .describe('l', 'Local address.')
    .describe('r', 'Remote address.')
    .describe('t', 'Socket type.')
    .argv;

if (argv.h) {
    Opt.showHelp();
    process.exit(0);
}

// parse and validate port number
function parsePort(port) {
    if ((port + '').match(/^[0-9]+$/i)) {
        return parseInt(port);
    }

    console.log(port + ' is not a valid port number.');
    process.exit(1);
}

// parse and validate ip address
function parseAddress(address) {
    var parsed = (address + '').split(':'),
        result = {};

    if (parsed.length > 1) {
        isIP = Net.isIP(parsed[0]);

        if (!isIP) {
            console.log(parsed[0] + ' is not a valid ip address.');
            process.exit(1);
        }

        result = {ip : parsed[0], port : parsePort(parsed[1]), type : isIP};
    } else {
        result = {ip : '0.0.0.0', port : parsePort(parsed[0]), type : 4}
    }

    return result;
}

var localAddress = parseAddress(argv.l),
    remoteAddress = parseAddress(argv.r);

if (argv.t == 'tcp') {
    var server = Net.Server(function (client) {
        var socket = Net.connect(remoteAddress.port, remoteAddress.ip);
        client.pipe(socket).pipe(client);
    
        console.log("Request " + client.remoteAddress 
            + ":" + client.remotePort);

        client.on('error', function (err) {
            console.log("Error " + err);
        });
    });

    server.listen(localAddress.port, localAddress.ip);

    server.on('error', function (err) {
        console.log("Error " + err);
    });
} else {
    var receiver = Udp.createSocket('udp' + localAddress.type),
        sender = Udp.createSocket('udp' + remoteAddress.type),
        client = null;

    receiver.bind(localAddress.port, localAddress.ip);
    receiver.ref();
    sender.bind();
    sender.ref();

    receiver.on('error', function (err) {
        console.log("Error " + err);
    });
    
    sender.on('error', function (err) {
        console.log("Error " + err);
    });

    receiver.on('message', function (data, info) {
        client = info;

        console.log("Request " + client.address
            + ":" + client.port);

        sender.send(data, 0, data.length, remoteAddress.port, remoteAddress.ip);
    });

    sender.on('message', function (data, info) {
        console.log("Response " + info.address
            + ":" + info.port);

        if (client) {
            receiver.send(data, 0, data.length, client.port, client.address);
        }
    });
}


console.log("Piping " + localAddress.ip + ":" + localAddress.port 
    + " to " + remoteAddress.ip + ":" + remoteAddress.port + " via " + argv.t);

