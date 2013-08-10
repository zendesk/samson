/**
 * Module dependencies:
 * express
 * redis
 */

var express = require('express'),
    redis   = require('redis');

var app = express();

// Configuration
app.configure(function(){
  app.use(app.router);
});

app.configure('development', function(){
  app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));
});

app.configure('production', function(){
  app.use(express.errorHandler());
});

// Routes

app.get('/jobs/:channel/stream', function(req, res) {
  // let request last as long as possible
  req.socket.setTimeout(Infinity);

  var subscriber = redis.createClient();
  subscriber.subscribe(req.params.channel);

  // In case we encounter an error...print it out to the console
  subscriber.on("error", function(err) {
    console.log("Redis Error: " + err);
  });

  // When we receive a message from the redis connection
  subscriber.on("message", function(channel, message) {
    if(message != "") {
      res.write('data:' + JSON.stringify({ msg: message }) + '\n\n');
    }
  });

  //send headers for event-stream connection
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Access-Control-Allow-Origin': '*'
  });
  res.write('\n');

  // The 'close' event is fired when a user closes their browser window.
  // In that situation we want to make sure our redis channel subscription
  // is properly shut down to prevent memory leaks...and incorrect subscriber
  // counts to the channel.
  req.on("close", function() {
    subscriber.unsubscribe();
    subscriber.quit();
  });
});

app.listen(8081);
console.log("Express server listening in %s mode", app.settings.env);
