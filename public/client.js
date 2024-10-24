const serverAddress = window.location.hostname;

const app = Elm.Main.init({
    node: document.getElementById('elm'),
});

const socket = new WebSocket(`ws://${serverAddress}:8001`);

socket.onmessage = (event) => {
    app.ports.onWebsocketMessage.send(event.data);
};

app.ports.alert.subscribe((message) => {
    alert(message);
});

app.ports.sendWebsocketMessage.subscribe((message) => {
    socket.send(message);
});