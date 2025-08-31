# Sample Voting Application

A polyglot microservices voting application that demonstrates modern cloud-native development patterns including event-driven architecture, real-time WebSocket communication, and containerized development workflows.

## 🏗️ Architecture

![Architecture diagram](architecture.excalidraw.png)

### Components

This application consists of five main components that work together to create a distributed voting system:

#### **Vote Service** 🗳️
- **Technology**: Python 3.11 + Flask
- **Port**: 5000 (development)
- **Purpose**: Frontend voting interface
- **Features**:
  - Web form for vote submission
  - Cookie-based vote tracking (prevents duplicate voting)
  - Asynchronous vote queuing to Redis
  - Hot-reload development support with volume mounting

#### **Result Service** 📊
- **Technology**: Node.js 18 + Socket.IO
- **Port**: 5001 (development)
- **Purpose**: Real-time results dashboard
- **Features**:
  - Live vote tallies with WebSocket updates
  - Responsive visualization of voting percentages
  - PostgreSQL integration for persistent data
  - Auto-refresh when new votes arrive

#### **Worker Service** ⚙️
- **Technology**: .NET 7.0 (C#)
- **Port**: Background service (no HTTP port)
- **Purpose**: Asynchronous vote processor
- **Features**:
  - Consumes votes from Redis queue
  - Validates and processes vote data
  - Persists final vote records to PostgreSQL
  - Handles high-throughput vote processing

#### **Redis Cache** 🔄
- **Technology**: Redis Alpine
- **Port**: 6379
- **Purpose**: Message queue and session storage
- **Features**:
  - High-performance vote queuing
  - Temporary vote storage
  - Session state management

#### **PostgreSQL Database** 🗄️
- **Technology**: PostgreSQL 15
- **Port**: 5432
- **Purpose**: Persistent data storage
- **Features**:
  - Durable vote record storage
  - ACID transaction support
  - Volume-backed data persistence

### Data Flow

```
User Vote → Vote Service → Redis Queue → Worker Service → PostgreSQL → Result Service → Live Update
```

1. **Vote Submission**: User clicks vote button → Vote service validates and queues to Redis
2. **Asynchronous Processing**: Worker service dequeues votes → processes and stores in PostgreSQL
3. **Real-time Updates**: Result service polls database → pushes updates via WebSocket to connected clients

## 🚀 Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) 20.10+
- [Docker Compose](https://docs.docker.com/compose/install/) 2.0+

### Run the Application

```bash
# Clone or navigate to the application directory
cd src/sample-app

# Start all services
docker-compose up

# Or run in detached mode
docker-compose up -d
```

### Access the Application

- **Vote Interface**: http://localhost:5000
- **Results Dashboard**: http://localhost:5001
- **PostgreSQL**: localhost:5432 (postgres/password)
- **Redis**: localhost:6379

## 🛠️ Development

### Hot-Reload Development

The development environment supports hot-reloading for rapid iteration:

#### Python (Vote Service)
- **Auto-reload**: Flask development mode with file watching
- **Volume mounting**: `./vote` → `/usr/local/app`
- **Dependencies**: Install with `pip install -r vote/requirements.txt`

#### Node.js (Result Service)
- **Auto-reload**: Nodemon for file watching
- **Volume mounting**: `./result` → `/usr/local/app`
- **Dependencies**: Install with `npm install` in `result/` directory

#### .NET (Worker Service)
- **Rebuild required**: `docker-compose build worker` after code changes
- **Hot-reload**: Not supported in containerized mode

### Development Commands

```bash
# Start development environment
docker-compose up

# Rebuild specific service
docker-compose build vote
docker-compose build result
docker-compose build worker

# View logs
docker-compose logs vote
docker-compose logs result
docker-compose logs worker
docker-compose logs -f  # Follow all logs

# Stop services
docker-compose down

# Clean up (removes volumes and data)
docker-compose down -v
```

### Environment Variables

#### Vote Service
- `FLASK_ENV=development` - Enables debug mode and hot-reload
- `REDIS_HOST=redis` - Redis connection hostname
- `OPTION_A` - First voting option (default: "Cats")
- `OPTION_B` - Second voting option (default: "Dogs")

#### Result Service
- `NODE_ENV=development` - Enables development mode
- `DATABASE_URL=postgres://postgres:password@db:5432/votes` - PostgreSQL connection

#### Worker Service
- `REDIS_HOST=redis` - Redis connection hostname
- `DATABASE_URL=postgres://postgres:password@db:5432/votes` - PostgreSQL connection

## 🧪 Testing

### Manual Testing

1. **Vote Submission**:
   - Visit http://localhost:5000
   - Click voting buttons to submit votes
   - Verify votes are recorded (check browser cookies)

2. **Real-time Results**:
   - Open http://localhost:5001 in multiple browser tabs
   - Submit votes and observe real-time updates
   - Verify percentages update correctly

3. **Data Persistence**:
   - Submit several votes
   - Restart services: `docker-compose restart`
   - Verify vote data persists after restart

### Automated Testing

```bash
# Run result service tests
docker-compose run --rm result npm test

# Generate test data
docker-compose run --rm seed-data
```

### Health Checks

```bash
# Check service health
curl http://localhost:5000/  # Vote service
curl http://localhost:5001/  # Result service

# Check database connectivity
docker-compose exec db pg_isready -U postgres

# Check Redis connectivity
docker-compose exec redis redis-cli ping
```

## 🐛 Troubleshooting

### Common Issues

#### Vote Service Not Accessible
```bash
# Check if service is running
docker-compose ps vote

# View logs for errors
docker-compose logs vote

# Verify Redis connectivity
docker-compose exec vote python -c "import redis; r=redis.Redis(host='redis'); print(r.ping())"
```

#### Result Service WebSocket Issues
```bash
# Check Node.js service logs
docker-compose logs result

# Verify database connectivity
docker-compose exec result node -e "const { Pool } = require('pg'); const pool = new Pool({connectionString: process.env.DATABASE_URL}); pool.query('SELECT NOW()', (err, res) => { console.log(err ? err : res.rows[0]); pool.end(); });"
```

#### Worker Service Not Processing
```bash
# Check worker logs
docker-compose logs worker

# Verify Redis queue has items
docker-compose exec redis redis-cli llen votes

# Check database for processed votes
docker-compose exec db psql -U postgres -d votes -c "SELECT vote, COUNT(*) FROM votes GROUP BY vote;"
```

#### Database Connection Issues
```bash
# Check PostgreSQL status
docker-compose exec db pg_isready -U postgres -d votes

# Reset database
docker-compose down -v
docker-compose up db
```

### Port Conflicts

If default ports are in use, modify `docker-compose.yml`:

```yaml
services:
  vote:
    ports:
      - "5010:80"  # Change from 5000 to 5010
  result:
    ports:
      - "5011:80"  # Change from 5001 to 5011
```

## 📊 Monitoring

### View Application Metrics

```bash
# Container resource usage
docker stats

# Service-specific stats
docker stats sample-app-vote-1 sample-app-result-1 sample-app-worker-1

# Database activity
docker-compose exec db psql -U postgres -d votes -c "SELECT * FROM pg_stat_activity;"

# Redis statistics
docker-compose exec redis redis-cli info stats
```

### Database Queries

```sql
-- Connect to database
docker-compose exec db psql -U postgres -d votes

-- View all votes
SELECT * FROM votes;

-- Vote tally
SELECT vote, COUNT(*) as count FROM votes GROUP BY vote;

-- Recent votes (if timestamp column exists)
SELECT * FROM votes ORDER BY id DESC LIMIT 10;
```

## 🔧 Customization

### Change Voting Options

Modify environment variables in `docker-compose.yml`:

```yaml
services:
  vote:
    environment:
      - OPTION_A=React
      - OPTION_B=Vue
      - FLASK_ENV=development
      - REDIS_HOST=redis
```

### Custom Styling

- **Vote Service**: Edit `vote/static/stylesheets/style.css`
- **Result Service**: Edit `result/views/stylesheets/style.css`

Changes will hot-reload automatically in development mode.

### Database Schema

The application creates a simple `votes` table:

```sql
CREATE TABLE votes (
  id SERIAL PRIMARY KEY,
  voter_id VARCHAR(255) NOT NULL,
  vote VARCHAR(1) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 🎯 Production Considerations

### Security
- Remove development environment variables
- Use secrets management for database credentials
- Implement proper authentication and authorization
- Enable HTTPS/TLS for all services

### Scalability
- Scale vote service horizontally for high load
- Use Redis Cluster for queue scalability
- Implement database connection pooling
- Add load balancing for result service WebSockets

### Monitoring
- Add structured logging to all services
- Implement health check endpoints
- Set up metrics collection (Prometheus/Grafana)
- Configure alerting for service failures

---

## 📝 Notes

- The application accepts only one vote per browser session (cookie-based)
- This is a demonstration application focused on showcasing microservices patterns
- Not intended for production use without additional security and scalability measures
- WebSocket connections provide real-time updates but may require additional configuration in production environments
