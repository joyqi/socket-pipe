
var Opt = require('optimist'),
    Net = require('net'),
    Udp = require('dgram')
    Event = require('events');


var argv = Opt
    .usage('Usage: $0 [ -l 80 ] [ -r 10.0.10.11:80 ] [ -t udp ]')
    .demand(['l', 'r'])
    .boolean('h')
    .alias('t', 'type')
    .alias('h', 'help')
    .alias('l', 'local')
    .alias('r', 'remote')
    .alias('x', 'transfer')
    .alias('s', 'specify')
    .default('t', 'tcp')
    .describe('l', 'Local address.')
    .describe('r', 'Remote address.')
    .describe('t', 'Socket type.')
    .describe('x', 'Transfer option.')
    .describe('s', 'Specify option.')
    .argv;

if (argv.h) {
    Opt.showHelp();
    process.exit(0);
}

var localAddress = parseAddress(argv.l),
    remoteAddress = parseAddress(argv.r);

// parse and validate port number
function parsePort(port) {
    if ((port + '').match(/^[0-9]+$/i)) {
        return parseInt(port);
    }

    if ((port + '').match(/^[0-9]+\-[0-9]+$/i)) {
        parsed = (port + '').split('-');
        return [parseInt(parsed[0]), parseInt(parsed[1])];
    }

    console.log(port + ' is not a valid port number.');
    process.exit(1);
}

// parse and validate ip address
function parseAddress(address) {
    var parsed = (address + '').split('@'),
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

Adapter = require('./build/' + argv.t);
new Adapter(localAddress, remoteAddress, argv.x, argv.s);

console.log("Piping " + localAddress.ip + "@" + localAddress.port 
    + " to " + remoteAddress.ip + "@" + remoteAddress.port + " via " + argv.t);

