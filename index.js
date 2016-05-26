
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

var localAddress = parseAddress(argv.l),
    remoteAddress = parseAddress(argv.r),
    connectionPool = {};

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

// request a udp socket from pool
function requestUdpSocket(info) {
    var key = info.address + '@' + info.port,
        now = Date.now();

    if (connectionPool[key]) {
        connectionPool[key].time = now;
    } else {
        var socket = Udp.createSocket('udp' + remoteAddress.type);
        socket.bind();

        socket.on('error', function (err) {
            console.log("Error " + err);
        });

        connectionPool[key] = {time : now, socket : socket};
    }
    
    return connectionPool[key].socket;
}

function requestUdpPort(port) {
    if (port instanceof Array) {
        return Math.floor(Math.random() * (port[1] - port[0] + 1)) + port[0];
    } else {
        return port;
    }
}

// connection collect
setInterval(function () {
    var now = Date.now(), expires = [];

    for (var key in connectionPool) {
        var connection = connectionPool[key];

        if (now - connection.time > 5000) {
            expires.push(key);
        }
    }

    for (var i = 0; i < expires.length; i ++) {
        var key = expires[i];

        connectionPool[key].socket.close();
        delete connectionPool[key];

        console.log("Close " + key);
    }
}, 5000);

if (argv.t == 'tcp') {
    // tcp pipe
    var server = Net.Server(function (client) {
        var socket = Net.connect(remoteAddress.port, remoteAddress.ip);
        client.pipe(socket).pipe(client);
    
        console.log("Request " + client.remoteAddress 
            + "@" + client.remotePort);

        client.on('error', function (err) {
            console.log("Error " + err);
        });
    });

    server.listen(localAddress.port, localAddress.ip);

    server.on('error', function (err) {
        console.log("Error " + err);
    });
} else {
    // udp pipe
    var receiver = Udp.createSocket('udp' + localAddress.type);

    receiver.bind(localAddress.port, localAddress.ip);
    receiver.ref();

    receiver.on('error', function (err) {
        console.log("Error " + err);
    }); 

    receiver.on('message', function (data, info) {
        var sender = requestUdpSocket(info),
            client = info;

        sender.on('message', function (data, info) {
            console.log("Response " + info.address
                + "@" + info.port);

            receiver.send(data, 0, data.length, client.port, client.address);
        });

        console.log("Request " + client.address
            + "@" + client.port);

        sender.send(data, 0, data.length, requestUdpPort(remoteAddress.port), remoteAddress.ip);
    });
}


console.log("Piping " + localAddress.ip + "@" + localAddress.port 
    + " to " + remoteAddress.ip + "@" + remoteAddress.port + " via " + argv.t);

