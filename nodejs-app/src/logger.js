'use strict';

const winston = require('winston');
const LokiTransport = require('winston-loki');

const LOKI_HOST = process.env.LOKI_HOST || 'http://localhost:3100';
const APP_NAME = process.env.LOKI_LABEL_APP || 'nodejs-app';
const ENVIRONMENT = process.env.LOKI_LABEL_ENV || process.env.NODE_ENV || 'development';
const INSTANCE_ID = process.env.INSTANCE_ID || 'local-dev';

const transports = [
  new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
      winston.format.printf(({ timestamp, level, message, ...meta }) => {
        const metaStr = Object.keys(meta).length ? ` ${JSON.stringify(meta)}` : '';
        return `${timestamp} [${level}]: ${message}${metaStr}`;
      })
    ),
  }),
];

// Add Loki transport if host is configured
try {
  const lokiTransport = new LokiTransport({
    host: LOKI_HOST,
    labels: {
      app: APP_NAME,
      environment: ENVIRONMENT,
      instance: INSTANCE_ID,
    },
    json: true,
    format: winston.format.json(),
    replaceTimestamp: true,
    onConnectionError: (err) => {
      console.error(`[Logger] Loki connection error: ${err.message}`);
    },
  });
  transports.push(lokiTransport);
} catch (err) {
  console.error(`[Logger] Failed to initialize Loki transport: ${err.message}`);
}

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: APP_NAME,
    instance: INSTANCE_ID,
  },
  transports,
});

module.exports = logger;
