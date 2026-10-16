import { WebSocketServer, WebSocket } from 'ws';
import { Server } from 'http';

let wss: WebSocketServer | null = null;

export const initWebSocketServer = (server: Server) => {
  wss = new WebSocketServer({ server });

  wss.on('connection', (ws) => {
    console.log('📱 [WEBSOCKET] Client mobile terhubung.');

    ws.on('close', () => {
      console.log('📱 [WEBSOCKET] Client mobile terputus.');
    });

    ws.on('error', (err) => {
      console.error('❌ [WEBSOCKET ERROR]:', err);
    });
  });

  console.log('⚡ WebSocket Server berhasil diaktifkan.');
};

export const broadcastWebSocket = (data: any) => {
  if (!wss) return;

  const payload = JSON.stringify(data);
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(payload);
    }
  });
};