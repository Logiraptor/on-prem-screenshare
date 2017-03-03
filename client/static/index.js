var output = document.getElementById('output');
var spool = "";

var ws = new WebSocket("ws://localhost:3000/feed");
ws.onmessage = function(message) {
    var delim = "^^^";
    var eos = message.data.indexOf(delim);
    if (eos != -1) {
        spool += message.data.substring(0, eos);
        console.log(message.data);
        console.log(eos);
        console.log(spool);
        output.src = "data:image/jpeg;base64, " + spool;
        spool = message.data.substring(eos + delim.length);
    } else {
        spool += message.data;
    }
};

ws.onopen = function() {
    console.log("onopen");
};

ws.onclose = function() {
    console.log("onclose");
}
