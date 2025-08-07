import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import { Pool } from 'pg';
import cookieParser from 'cookie-parser';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const server = createServer(app);
const io = new Server(server);

const port = process.env.PORT || 4000;
const dbUrl = process.env.DATABASE_URL || 'postgres://postgres:postgres@db/postgres';

console.log(`Starting result service on port ${port}`);
console.log(`Database URL: ${dbUrl}`);

// Socket.io connection handling
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);

  socket.emit('message', { text: 'Welcome to real-time results!' });

  socket.on('subscribe', (data) => {
    socket.join(data.channel);
    console.log(`Client ${socket.id} subscribed to ${data.channel}`);
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

// PostgreSQL connection with enhanced error handling
const pool = new Pool({
  connectionString: dbUrl,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Enhanced database connection with retry logic
async function connectToDatabase(retries = 1000) {
  for (let i = 0; i < retries; i++) {
    try {
      const client = await pool.connect();
      console.log('Connected to database successfully');
      client.release();
      return true;
    } catch (err) {
      console.error(`Database connection attempt ${i + 1}/${retries} failed:`, err.message);
      if (i < retries - 1) {
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
  }
  console.error('Failed to connect to database after all retries');
  return false;
}

// Enhanced vote polling with better error handling
async function getVotes() {
  try {
    const result = await pool.query('SELECT vote, COUNT(id) AS count FROM votes GROUP BY vote');
    const votes = collectVotesFromResult(result);

    // Emit to all connected clients
    io.sockets.emit('scores', JSON.stringify(votes));

    // Log current vote counts for debugging
    console.log('Current votes:', votes);
  } catch (err) {
    console.error('Error performing query:', err.message);

    // Emit error state to clients
    io.sockets.emit('error', { message: 'Database connection lost' });
  }

  // Continue polling
  setTimeout(getVotes, 1000);
}

function collectVotesFromResult(result) {
  const votes = { a: 0, b: 0 };

  result.rows.forEach((row) => {
    votes[row.vote] = parseInt(row.count, 10);
  });

  return votes;
}

// Middleware
app.use(cookieParser());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'views')));

// Routes
app.get('/', (req, res) => {
  res.sendFile(path.resolve(__dirname, 'views', 'index.html'));
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'result',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully');
  server.close(() => {
    pool.end(() => {
      process.exit(0);
    });
  });
});

// Start the application
async function startApplication() {
  const dbConnected = await connectToDatabase();

  if (dbConnected) {
    // Start polling for votes
    getVotes();

    // Start the server
    server.listen(port, () => {
      console.log(`Result service running on port ${port}`);
      console.log(`Health check available at http://localhost:${port}/health`);
    });
  } else {
    console.error('Could not establish database connection. Exiting.');
    process.exit(1);
  }
}

startApplication();
