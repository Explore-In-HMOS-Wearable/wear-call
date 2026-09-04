
/**
* Minimum signaling server for testing.
* Pairs two clients on the same Wi-Fi network, transmits JSON messages
* and raw PCM audio packets between them. No authentication — for local testing only. *
* Setup: npm install
* Execute: node signaling.js
*/
const { WebSocketServer } = require('ws');

const PORT = xxxx;
const wss = new WebSocketServer({ port: PORT, host: 'aaa.aaa.aaa.aaa' });

const clients = new Map();

const peers = new Map();

function log(...args) {
  console.info(new Date().toLocaleTimeString('tr-TR'), ...args);
}

function sendJson(socket, obj) {
  if (socket && socket.readyState === socket.OPEN) {
    socket.send(JSON.stringify(obj));
  }
}

function peerSocketOf(id) {
  const peerId = peers.get(id);
  return peerId ? clients.get(peerId) : null;
}

function teardown(id, notifyPeer) {
  const peerId = peers.get(id);
  if (peerId) {
    peers.delete(id);
    peers.delete(peerId);
    if (notifyPeer) {
      sendJson(clients.get(peerId), { t: 'bye' });
    }
  }
}

wss.on('connection', (socket) => {
  let myId = null;

  socket.on('message', (data, isBinary) => {
    if (isBinary) {
      const peer = peerSocketOf(myId);
      if (peer && peer.readyState === peer.OPEN) {
        peer.send(data, { binary: true });
      }
      return;
    }

    let msg;
    try {
      msg = JSON.parse(data.toString());
    } catch {
      log('Error');
      return;
    }

    switch (msg.t) {
      case 'hello': {
        myId = msg.id;
        clients.set(myId, socket);
        sendJson(socket, { t: 'welcome', id: myId, online: [...clients.keys()] });
        log(`bağlandı: ${myId} (toplam ${clients.size})`);
        break;
      }

      case 'invite': {
        const target = clients.get(msg.to);
        if (!target) {
          sendJson(socket, { t: 'unavailable', reason: 'offline' });
          log(`${myId} -> ${msg.to}: Offline`);
          return;
        }
        if (peers.has(msg.to)) {
          sendJson(socket, { t: 'unavailable', reason: 'busy' });
          return;
        }
        peers.set(myId, msg.to);
        peers.set(msg.to, myId);
        sendJson(target, { t: 'invite', from: myId, name: msg.name || myId });
        sendJson(socket, { t: 'ringing' });
        log(`${myId} -> ${msg.to}: arıyor`);
        break;
      }

      case 'accept': {
        sendJson(peerSocketOf(myId), { t: 'accept' });
        log(`${myId}: cevapladı`);
        break;
      }

      case 'reject': {
        sendJson(peerSocketOf(myId), { t: 'reject' });
        teardown(myId, false);
        log(`${myId}: reddetti`);
        break;
      }

      case 'bye': {
        teardown(myId, true);
        log(`${myId}: Closed`);
        break;
      }

      default:
        log(`Unknown message type: ${msg.t}`);
    }
  });

  socket.on('close', () => {
    if (myId) {
      teardown(myId, true);
      clients.delete(myId);
      log(`left: ${myId} (remaining ${clients.size})`);
    }
  });

  socket.on('error', (err) => log('socket error:', err.message));
});

log(`Signaling server ready: ws://xx.xx.xx.xx:${PORT}`);
log('Address to give to phones: ws://<your-computer-LAN-IP-address>:8080')
