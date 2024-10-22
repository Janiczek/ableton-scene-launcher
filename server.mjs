import { Ableton } from "ableton-js";
import WebSocket, { WebSocketServer } from 'ws';
import express from 'express';
import { networkInterfaces } from 'os';


const httpPort = 8000;
const wsPort = 8001;

const ipAddress = Object.values(networkInterfaces())
  .flat()
  .find(iface => !iface.internal && iface.family === 'IPv4')?.address || 'localhost';

// --------------------------------
// HTTP SERVER 

const httpServer = express();

httpServer.use(express.static('public'));
httpServer.listen(httpPort);
console.log("HTTP server listening on port", httpPort);

// --------------------------------
// WEBSOCKET SERVER->CLIENT MSGS 

const msg_ = (msg, data) => JSON.stringify({ msg, ...data });
const msg = {
  scenes: (s) => msg_("scenes", { scenes: s }),
};

// --------------------------------
// ABLETON

const ableton = new Ableton({ logger: console });
await ableton.start();
let scenes = await ableton.song.get("scenes");
let sceneMetadata = await getSceneMetadata(scenes);

// --------------------------------
// WEBSOCKET SERVER

const wss = new WebSocketServer({ port: wsPort });
console.log("WebSocket server listening on port", wsPort);

wss.on('connection', function connection(ws) {
  console.log("Client connected, sending scenes");

  ws.on('error', console.error);

  ws.on('message', async function message(data) {
    console.log('received: %s', data);
    const json = JSON.parse(data);
    await update(json);
  });

  // Init with the scenes
  ws.send(msg.scenes(sceneMetadata));
});

// --------------------------------
// BUSINESS LOGIC

ableton.song.addListener("scenes", async (s) => {
  scenes = s;
  sceneMetadata = await getSceneMetadata(s);
  const m = msg.scenes(sceneMetadata);
  onEachClient((client) => client.send(m));
});

async function update(msg) {
  switch (msg.msg) {
    case "TriggerScene":
      await scenes[msg.index].fire();
      break;
    default:
      console.error('Unknown frontend->backend message:', msg);
  }
}


console.log(`Ready to receive connections, open the browser at http://${ipAddress}:${httpPort}`);

// --------------------------------
// HELPERS

async function getSceneMetadata(scenes) {
  return Promise.all(scenes.map(async (scene, index) => ({
    name: await scene.get("name"),
    color: (await scene.get("color")).toString(),
    index,
  })));
}

function onEachClient(fn) {
  wss.clients.forEach(function each(client) {
    if (client.readyState === WebSocket.OPEN) {
      fn(client);
    }
  });
};
