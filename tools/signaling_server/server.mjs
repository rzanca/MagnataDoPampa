#!/usr/bin/env node
/**
 * Magnata do Pampa — Servidor Leve de Sinalização WebRTC (Topologia Estrela)
 * Zero dependências externas (usa apenas módulos nativos do Node.js 18+: http + crypto).
 *
 * Suporta salas por Código de Sala com 1 Host (peer_id = 1) + até 5 Clientes (peer_id = 2..6).
 * Uso:
 *   node signaling_server/server.mjs
 *   PORT=9080 node signaling_server/server.mjs
 */

import http from "node:http";
import crypto from "node:crypto";

const PORT = Number(process.env.PORT || 9080);
const HOST = process.env.HOST || "0.0.0.0";
const MAX_CLIENTS_LIMIT = 5;
const WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // sem 0/O/1/I para fácil leitura

/** @type {Map<string, { code: string, host: WsClient, hostName: string, maxClients: number, nextPeerId: number, clients: Map<number, { ws: WsClient, name: string }> }>} */
const rooms = new Map();

function generateRoomCode() {
  for (let attempt = 0; attempt < 40; attempt++) {
    let code = "";
    for (let i = 0; i < 6; i++) {
      code += CODE_ALPHABET[crypto.randomInt(0, CODE_ALPHABET.length)];
    }
    if (!rooms.has(code)) return code;
  }
  return crypto.randomBytes(3).toString("hex").toUpperCase();
}

function encodeWsFrame(payloadBuf, opcode = 0x1) {
  const len = payloadBuf.length;
  let header;
  if (len < 126) {
    header = Buffer.alloc(2);
    header[0] = 0x80 | opcode;
    header[1] = len;
  } else if (len < 65536) {
    header = Buffer.alloc(4);
    header[0] = 0x80 | opcode;
    header[1] = 126;
    header.writeUInt16BE(len, 2);
  } else {
    header = Buffer.alloc(10);
    header[0] = 0x80 | opcode;
    header[1] = 127;
    header.writeBigUInt64BE(BigInt(len), 2);
  }
  return Buffer.concat([header, payloadBuf]);
}

class WsClient {
  constructor(socket) {
    this.socket = socket;
    this.buffer = Buffer.alloc(0);
    this.closed = false;
    this.roomCode = "";
    this.peerId = 0;
    this.isHost = false;
    this.name = "Estanceiro";

    socket.on("data", (chunk) => this._onData(chunk));
    socket.on("close", () => this._handleClose());
    socket.on("error", () => this._handleClose());
  }

  sendJson(obj) {
    if (this.closed || this.socket.destroyed) return;
    const buf = Buffer.from(JSON.stringify(obj), "utf8");
    try {
      this.socket.write(encodeWsFrame(buf, 0x1));
    } catch {
      this._handleClose();
    }
  }

  close() {
    if (this.closed) return;
    this.closed = true;
    try {
      this.socket.write(encodeWsFrame(Buffer.alloc(0), 0x8));
      this.socket.end();
    } catch {
      // ignore
    }
  }

  _onData(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    while (this.buffer.length >= 2) {
      const b0 = this.buffer[0];
      const b1 = this.buffer[1];
      const opcode = b0 & 0x0f;
      const masked = (b1 & 0x80) !== 0;
      let payloadLen = b1 & 0x7f;
      let offset = 2;

      if (payloadLen === 126) {
        if (this.buffer.length < 4) return;
        payloadLen = this.buffer.readUInt16BE(2);
        offset = 4;
      } else if (payloadLen === 127) {
        if (this.buffer.length < 10) return;
        payloadLen = Number(this.buffer.readBigUInt64BE(2));
        offset = 10;
      }

      const maskLen = masked ? 4 : 0;
      if (this.buffer.length < offset + maskLen + payloadLen) return;

      const maskKey = masked ? this.buffer.subarray(offset, offset + 4) : null;
      offset += maskLen;
      const payload = Buffer.from(this.buffer.subarray(offset, offset + payloadLen));
      this.buffer = this.buffer.subarray(offset + payloadLen);

      if (masked && maskKey) {
        for (let i = 0; i < payload.length; i++) {
          payload[i] ^= maskKey[i % 4];
        }
      }

      if (opcode === 0x8) {
        this._handleClose();
        return;
      }
      if (opcode === 0x9) {
        // Ping -> Pong
        try {
          this.socket.write(encodeWsFrame(payload, 0xa));
        } catch {
          this._handleClose();
        }
        continue;
      }
      if (opcode === 0x1) {
        this._handleText(payload.toString("utf8"));
      }
    }
  }

  _handleText(raw) {
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }
    if (!msg || typeof msg !== "object") return;
    handleSignalingMessage(this, msg);
  }

  _handleClose() {
    if (this.closed) return;
    this.closed = true;
    handleClientDisconnect(this);
  }
}

function handleSignalingMessage(client, msg) {
  const type = String(msg.type || "");

  if (type === "create_room") {
    handleClientDisconnect(client);
    const code = generateRoomCode();
    const hostName = String(msg.name || "Anfitrião").trim().slice(0, 22) || "Anfitrião";
    const maxClients = Math.max(1, Math.min(MAX_CLIENTS_LIMIT, Number(msg.max_clients || MAX_CLIENTS_LIMIT)));
    client.roomCode = code;
    client.peerId = 1;
    client.isHost = true;
    client.name = hostName;
    rooms.set(code, {
      code,
      host: client,
      hostName,
      maxClients,
      nextPeerId: 2,
      clients: new Map()
    });
    console.log(`[SALA +] ${code} criada por ${hostName} (até ${maxClients + 1} estanceiros)`);
    client.sendJson({ type: "room_created", room_code: code, peer_id: 1 });
    return;
  }

  if (type === "join_room") {
    handleClientDisconnect(client);
    const code = String(msg.room_code || "").trim().toUpperCase();
    const guestName = String(msg.name || "Estanceiro").trim().slice(0, 22) || "Estanceiro";
    const room = rooms.get(code);
    if (!room) {
      client.sendJson({ type: "error", message: `Sala '${code}' não encontrada. Confira o código com o Host.` });
      return;
    }
    if (room.clients.size >= room.maxClients) {
      client.sendJson({ type: "error", message: `A sala ${code} já atingiu o limite máximo de 6 estanceiros.` });
      return;
    }
    const peerId = room.nextPeerId++;
    client.roomCode = code;
    client.peerId = peerId;
    client.isHost = false;
    client.name = guestName;
    room.clients.set(peerId, { ws: client, name: guestName });

    console.log(`[PEER +] ${guestName} (peer ${peerId}) entrou na sala ${code} (${room.clients.size + 1}/6)`);
    client.sendJson({
      type: "room_joined",
      room_code: code,
      peer_id: peerId,
      host_name: room.hostName
    });
    room.host.sendJson({
      type: "peer_joined",
      peer_id: peerId,
      name: guestName
    });
    return;
  }

  // Encaminhamento estritamente em estrela: Host (1) <-> Cliente (peerId >= 2)
  if (type === "offer" || type === "answer" || type === "candidate") {
    const room = rooms.get(client.roomCode);
    if (!room) return;
    const targetId = Number(msg.target_id || 0);
    let targetWs = null;
    if (client.isHost && targetId >= 2) {
      const entry = room.clients.get(targetId);
      if (entry) targetWs = entry.ws;
    } else if (!client.isHost && targetId === 1) {
      targetWs = room.host;
    }
    if (!targetWs) return;

    const relayed = { ...msg, from_id: client.peerId };
    delete relayed.target_id;
    targetWs.sendJson(relayed);
  }
}

function handleClientDisconnect(client) {
  if (!client.roomCode) return;
  const code = client.roomCode;
  const room = rooms.get(code);
  client.roomCode = "";
  if (!room) return;

  if (client.isHost) {
    console.log(`[SALA -] ${code} encerrada (Host desconectou)`);
    for (const entry of room.clients.values()) {
      entry.ws.sendJson({ type: "host_left", reason: "O Host encerrou a sala de sinalização." });
      entry.ws.roomCode = "";
    }
    rooms.delete(code);
  } else if (room.clients.has(client.peerId)) {
    room.clients.delete(client.peerId);
    console.log(`[PEER -] peer ${client.peerId} saiu da sinalização da sala ${code}`);
    room.host.sendJson({ type: "peer_left", peer_id: client.peerId });
  }
}

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
    res.end(JSON.stringify({ ok: true, service: "magnata-do-pampa-signaling", active_rooms: rooms.size }));
    return;
  }
  res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
  res.end("Magnata do Pampa WebRTC Signaling Server (WebSocket)\n");
});

server.on("upgrade", (req, socket) => {
  const key = req.headers["sec-websocket-key"];
  if (!key) {
    socket.destroy();
    return;
  }
  const accept = crypto.createHash("sha1").update(key + WS_GUID).digest("base64");
  const headers = [
    "HTTP/1.1 101 Switching Protocols",
    "Upgrade: websocket",
    "Connection: Upgrade",
    `Sec-WebSocket-Accept: ${accept}`,
    "\r\n"
  ];
  socket.write(headers.join("\r\n"));
  new WsClient(socket);
});

server.listen(PORT, HOST, () => {
  console.log(`Magnata do Pampa — Signaling WebSocket ativo em ws://${HOST}:${PORT} (health: /health)`);
});
