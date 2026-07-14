'use strict';

require('dotenv').config();

const express = require('express');
const logger = require('./logger');
const { metricsMiddleware, metricsEndpoint, activeConnections } = require('./metrics');

const app = express();
const PORT = process.env.PORT || 3000;
const INSTANCE_ID = process.env.INSTANCE_ID || 'local-dev';

// Middleware
app.use(express.json());
app.use(metricsMiddleware);

// Request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info('HTTP Request', {
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('user-agent'),
      ip: req.ip,
    });
  });
  next();
});

// Track active connections
app.use((req, res, next) => {
  activeConnections.inc();
  res.on('finish', () => {
    activeConnections.dec();
  });
  next();
});

// Routes
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    instanceId: INSTANCE_ID,
    timestamp: new Date().toISOString(),
    version: '1.0.0',
  });
});

app.get('/', (req, res) => {
  res.json({
    app: 'nodejs-loki-app',
    version: '1.0.0',
    description: 'Node.js application with Grafana Loki logging',
    instanceId: INSTANCE_ID,
    endpoints: ['/health', '/api/users', '/api/orders', '/api/error', '/api/slow', '/metrics'],
  });
});

app.get('/api/users', (req, res) => {
  logger.info('Fetching users list');
  const users = [
    { id: 1, name: 'Alice Johnson', email: 'alice@example.com', role: 'admin' },
    { id: 2, name: 'Bob Smith', email: 'bob@example.com', role: 'user' },
    { id: 3, name: 'Charlie Brown', email: 'charlie@example.com', role: 'user' },
    { id: 4, name: 'Diana Prince', email: 'diana@example.com', role: 'moderator' },
    { id: 5, name: 'Eve Wilson', email: 'eve@example.com', role: 'user' },
  ];
  res.json({ users, count: users.length, instanceId: INSTANCE_ID });
});

app.post('/api/orders', (req, res) => {
  const orderId = `ORD-${Date.now()}-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
  const order = {
    id: orderId,
    items: req.body.items || [],
    total: req.body.total || 0,
    status: 'created',
    createdAt: new Date().toISOString(),
    instanceId: INSTANCE_ID,
  };

  logger.info('Order created', { orderId, itemCount: order.items.length, total: order.total });
  res.status(201).json(order);
});

app.get('/api/error', (req, res, next) => {
  logger.error('Simulated error triggered', {
    errorType: 'SimulatedError',
    endpoint: '/api/error',
    instanceId: INSTANCE_ID,
  });
  const error = new Error('This is a simulated error for testing monitoring and alerting');
  error.statusCode = 500;
  next(error);
});

app.get('/api/slow', (req, res) => {
  const delay = Math.floor(Math.random() * 2000) + 1000; // 1-3 seconds
  logger.warn('Slow endpoint called', { delay: `${delay}ms`, instanceId: INSTANCE_ID });
  setTimeout(() => {
    res.json({
      message: 'Slow response completed',
      delay: `${delay}ms`,
      instanceId: INSTANCE_ID,
    });
  }, delay);
});

app.get('/metrics', metricsEndpoint);

// 404 handler
app.use((req, res) => {
  logger.warn('Route not found', { method: req.method, path: req.path });
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.method} ${req.path} not found`,
    instanceId: INSTANCE_ID,
  });
});

// Error handler
app.use((err, req, res, _next) => {
  const statusCode = err.statusCode || 500;
  logger.error('Unhandled error', {
    error: err.message,
    stack: err.stack,
    statusCode,
    path: req.path,
    method: req.method,
  });
  res.status(statusCode).json({
    error: statusCode === 500 ? 'Internal Server Error' : err.message,
    message: err.message,
    instanceId: INSTANCE_ID,
  });
});

// Start server
const server = app.listen(PORT, () => {
  logger.info(`Server started on port ${PORT}`, {
    port: PORT,
    instanceId: INSTANCE_ID,
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version,
  });
});

// Graceful shutdown
const gracefulShutdown = (signal) => {
  logger.info(`${signal} received. Starting graceful shutdown...`, { signal });
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });

  // Force shutdown after 10 seconds
  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

module.exports = app;
