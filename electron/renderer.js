// This file is required by the index.html file and will
// be executed in the renderer process for that window.
// All of the Node.js APIs are available in this process.
// const {desktopCapturer} = require('electron')

// desktopCapturer.getSources({types: ['window', 'screen']}, (error, sources) => {
//   if (error) throw error
//   for (let i = 0; i < sources.length; ++i) {
//     if (sources[i].name === 'Entire screen') {
//       navigator.webkitGetUserMedia({
//         audio: false,
//         video: {
//           mandatory: {
//             chromeMediaSource: 'desktop',
//             chromeMediaSourceId: sources[i].id,
//             minWidth: 1280,
//             maxWidth: 1280,
//             minHeight: 720,
//             maxHeight: 720
//           }
//         }
//       }, handleStream, handleError)
//       return
//     } else {
//         console.log(sources[i].name);
//     }
//   }
// })

// function handleStream (stream) {
//   document.querySelector('video').src = URL.createObjectURL(stream)
// }

// function handleError (e) {
//   console.log(e)
// }