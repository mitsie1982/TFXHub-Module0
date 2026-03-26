const winston = require('winston');
const net = require('net');

// Get configuration from environment
const logstashHost = process.env.LOGSTASH_HOST || 'localhost';
const logstashPort = parseInt(process.env.LOGSTASH_PORT || '5000', 10);

// Custom Logstash TCP transport — matches logstash.conf tcp input with json codec
class LogstashTCPTransport extends winston.Transport {
  constructor(options) {
    super(options);
    this.host = logstashHost;
    this.port = logstashPort;
  }

  log(info, callback) {
    const logData = {
      timestamp: new Date().toISOString(),
      level: info.level,
      message: info.message,
      service: 'winston-logger',
      environment: 'production',
      type: 'nodejs',
      ...info
    };

    const socket = new net.Socket();
    socket.connect(this.port, this.host, () => {
      socket.write(JSON.stringify(logData) + '\n', 'utf8', () => {
        socket.destroy();
      });
    });
    socket.on('error', () => socket.destroy()); // silently fail if Logstash unavailable

    if (callback) callback();
  }
}

// Create Winston logger
const logger = winston.createLogger({
  format: winston.format.json(),
  transports: [
    // Console output
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    }),
    // File logging
    new winston.transports.File({
      filename: '/var/log/tfxhub/winston.log',
      format: winston.format.json()
    }),
    // Logstash TCP transport
    new LogstashTCPTransport({})
  ]
});

// Log periodic messages to verify system is working
setInterval(() => {
  logger.info('Winston logger health check', {
    timestamp: new Date().toISOString(),
    service: 'winston-logger',
    type: 'nodejs',
    event: 'heartbeat'
  });
}, 5000);

// Create log directory if it doesn't exist
const fs = require('fs');
const logDir = '/var/log/tfxhub';
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

logger.info('Winston logger service started', {
  logstashHost,
  logstashPort,
  timestamp: new Date().toISOString(),
  type: 'nodejs'
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('Winston logger shutting down', {
    timestamp: new Date().toISOString(),
    type: 'nodejs'
  });
  process.exit(0);
});
