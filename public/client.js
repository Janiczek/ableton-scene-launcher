const abletonServerAddress = window.location.hostname;

const lyricslidesServerAddress = prompt("LyricSlides IP", abletonServerAddress);

document.getElementById('lyricslides-iframe').src = `http://${abletonServerAddress}:5115`;

const app = Elm.Main.init({
    node: document.getElementById('elm'),
});

const socket = new WebSocket(`ws://${abletonServerAddress}:8001`);

socket.onmessage = (event) => {
    app.ports.onWebsocketMessage.send(event.data);
};

app.ports.alert.subscribe((message) => {
    alert(message);
});

app.ports.sendWebsocketMessage.subscribe((message) => {
    socket.send(message);
});
