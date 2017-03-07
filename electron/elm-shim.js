const Elm = require('./elm.js');

var peerConnectionConfig = {
    'iceServers': [
        {'urls': 'stun:stun.services.mozilla.com'},
        {'urls': 'stun:stun.l.google.com:19302'},
    ]
};

const app = Elm.Main.fullscreen('localhost:3434');

var peerConnection = new RTCPeerConnection(peerConnectionConfig);

peerConnection.onicecandidate = (event) => {
    if(event.candidate != null) {
        app.ports.onIceCandidate.send(event.candidate);
    }
};

peerConnection.onaddstream = (event) => {
    app.ports.onAddStream.send(URL.createObjectURL(event.stream));
};

app.ports.addIceCandidate.subscribe((ice) => {
    peerConnection.addIceCandidate(new RTCIceCandidate(ice));
});

app.ports.setRemoteDescription.subscribe((sdp) => {
    peerConnection.setRemoteDescription(new RTCSessionDescription(sdp)).then(() => {
        if (sdp.type == 'offer') {
            peerConnection.createAnswer().then((sdp) => {
                peerConnection.setLocalDescription(sdp).then(() => {
                    app.ports.onAnswer.send(sdp);
                }).catch(errorHandler);;
            }).catch(errorHandler);;
        }
    }).catch(errorHandler);
});

app.ports.createOffer.subscribe(() => {
    captureScreen((stream) => {
        peerConnection.addStream(stream);
        peerConnection.createOffer().then((desc) => {
            peerConnection.setLocalDescription(desc).then(() => {
                app.ports.onOffer.send(desc);
            }).catch(errorHandler);;
        }).catch(errorHandler);;
    });
});

function errorHandler(e) {
    app.ports.errors.send(e.toString());
}

const {desktopCapturer} = require('electron');

function captureScreen(callback) {
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
                }, callback, errorHandler)
                return
            }
        }
    })
}




// create RTCPeerConnection
// set up listeners for ice candidates and streams
// when an ice candidate is received: signal that to the peer
//      the peer will call addIceCandidate to keep track
// when a stream is received: put it in a <video> or something
// You can add streams to your connection in order to share them with the remote

// createOffer should be called once the config is done to create an 'offer'
// this is a description of the sorts of things you support
// That offer is then signaled to the peer.
// The offer is also set ass the 'local' description.

// createAnswer should be called in response to receiving an offer.
// The offer is set as the 'remote' description, and the answer is set as the local.
