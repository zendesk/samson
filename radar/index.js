var fs = require('fs'),
    url = require('url'),
    http = require('http'),
    Radar = require('radar').server,
    dotenv = require('dotenv');

dotenv.load();

var server = http.createServer(function(req, res) {
  console.log('404', req.url);
  res.statusCode = 404;
  res.end();
});

// attach Radar server to the http server
var radar = new Radar();

console.log('Connecting to redis: ' + process.env.REDIS_HOST + ":" + process.env.REDIS_PORT);

radar.attach(server, {
  redis_host: process.env.REDIS_HOST,
  redis_port: process.env.REDIS_PORT
});

server.listen(process.env.RADAR_PORT);
console.log('Server listening on localhost:' + process.env.RADAR_PORT);
