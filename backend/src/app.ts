import express from 'express';
import http from 'http';
import cors from 'cors';
import dotenv from 'dotenv';
import apiRoutes from './routes/api.routes';
import { initWebSocketServer } from './services/websocket.service';
import { initMqttWorker } from './services/mqtt.service';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Main REST API Routes
app.use('/api', apiRoutes);

// Health Check Endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', service: 'Zero-Band Backend Server' });
});

// Create HTTP Server & Init WebSocket + MQTT
const server = http.createServer(app);

initWebSocketServer(server);
initMqttWorker();

server.listen(PORT, () => {
  console.log(`🚀 [SERVER READY] Berjalan di http://localhost:${PORT}`);
});