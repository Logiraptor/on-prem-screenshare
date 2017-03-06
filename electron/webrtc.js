var localVideo;
var localStream;
var remoteVideo;
var peerConnection;
var serverConnection;
var numClients;

var peerConnectionConfig = {
    'iceServers': [
        {'urls': 'stun:stun.services.mozilla.com'},
        {'urls': 'stun:stun.l.google.com:19302'},
    ]
};

const {desktopCapturer} = require('electron');

function pageReady() {
    localVideo = document.getElementById('localVideo');
    remoteVideo = document.getElementById('remoteVideo');
    var roomNameInput = document.getElementById('room-name');
    var startButton = document.getElementById("start-button");
    numClients = document.getElementById("numClients");
    startButton.addEventListener("click", function(e) {
        joinRoom(roomNameInput.value);
        start(true);
    });
}

function joinRoom(name) {
    serverConnection = new WebSocket('ws://127.0.0.1:3434/ws?room='+name);
    serverConnection.onmessage = gotMessageFromServer;

    var constraints = {
        video: true,
        audio: true,
    };

    desktopCapturer.getSources({types: ['window', 'screen']}, (error, sources) => {
        if (error) throw error
        for (let i = 0; i < sources.length; ++i) {
            if (sources[i].name === 'Entire screen') {
            navigator.webkitGetUserMedia({
                audio: false,
                video: {
                mandatory: {
                    chromeMediaSource: 'desktop',
                    chromeMediaSourceId: sources[i].id,
                    minWidth: 1280,
                    maxWidth: 1280,
                    minHeight: 720,
                    maxHeight: 720
                }
                }
            }, getUserMediaSuccess, errorHandler("getUserMedia"))
            return
            } else {
                console.log(sources[i].name);
            }
        }
    })
}

function getUserMediaSuccess(stream) {
    localStream = stream;
    localVideo.srcObject = stream;
}

function start(isCaller) {
    peerConnection = new RTCPeerConnection(peerConnectionConfig);
    peerConnection.onicecandidate = gotIceCandidate;
    peerConnection.onaddstream = gotRemoteStream;
    peerConnection.addStream(localStream);

    if(isCaller) {
        peerConnection.createOffer().then(createdDescription).catch(errorHandler("createOffer"));
    }
}

function gotMessageFromServer(message) {
    if(!peerConnection) start(false);

    console.log("JSON:", message.data);
    var signal = JSON.parse(message.data);

    if(signal.sdp) {
        peerConnection.setRemoteDescription(new RTCSessionDescription(signal.sdp)).then(function() {
            // Only create answers in response to offers
            if(signal.sdp.type == 'offer') {
                peerConnection.createAnswer().then(createdDescription).catch(errorHandler("createAnswer"));
            }
        }).catch(errorHandler("setRemoteDescription"));
    } else if(signal.ice) {
        peerConnection.addIceCandidate(new RTCIceCandidate(signal.ice)).catch(errorHandler("addIceCandidate"));
    } else if(signal.numClients) {
        numClients.innerHTML = signal.numClients + " people are here.";
    }
}

function gotIceCandidate(event) {
    if(event.candidate != null) {
        serverConnection.send(JSON.stringify({'ice': event.candidate}));
    }
}

function createdDescription(description) {
    console.log('got description');

    peerConnection.setLocalDescription(description).then(function() {
        serverConnection.send(JSON.stringify({'sdp': peerConnection.localDescription}));
    }).catch(errorHandler("setLocalDescription"));
}

function gotRemoteStream(event) {
    console.log('got remote stream');
    remoteVideo.srcObject = event.stream;
}

function errorHandler(from) {
    return function(error) {
        console.log(from, error);
    }
}

pageReady();