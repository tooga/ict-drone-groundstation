// Load the http module to create an http server.
var http = require('http');
var drone = require("ar-drone").createClient();
drone.config('general:navdata_demo', 'TRUE');

// Configure our HTTP server to respond with Hello World to all requests.
var server = http.createServer(function (request, response) {
  response.end();
});
// Listen on port 8000, IP defaults to 127.0.0.1
server.listen(8000);

var socket = require('socket.io-client')('http://shepherd-client.herokuapp.com');

socket.on('connect', function(){
	console.log("connected from 8000");
});

socket.on("/drone/move", function(cmd) {
	console.log("cmd move " + cmd.action);
	//drone[cmd.action](cmd.speed);
});
socket.on("/drone/drone", function(cmd) {
	console.log("cmd drone " + cmd.action);
	//drone[cmd.action]();
});

drone.on('navdata', function(data) {
    if(!data.demo) { return; } // ??

    var clientData = {
        flying: data.droneState.flying
    };

    var navdataClientKeys = ['controlState', 'flyState', 'batteryPercentage', 'altitudeMeters', 'clockwiseDegrees', 'frontBackDegrees', 'leftRightDegrees', 'xVelocity', 'yVelocity', 'zVelocity'];

    for(var i=0, n=navdataClientKeys.length; i<n; i++) {
        var k = navdataClientKeys[i];
        clientData[k] = data.demo[k];
    }

    socket.emit("navdata", clientData);
    //console.log(util.inspect(clientData, {colors:true}));
});

var currentImg = null;
var imageSendingPaused = false;
var index = 0;

drone.getPngStream().on("data", function (frame) {
    currentImg = frame;
	var imageData = {
		frame: frame,
		src: "/image/" + index++
	}
    socket.emit("image", imageData);
});

// Put a friendly message on the terminal
console.log("Server running at http://127.0.0.1:8000/");