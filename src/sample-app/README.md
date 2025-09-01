# Sample Voting Application

A polyglot microservices voting application demonstrating cloud-native development patterns with event-driven architecture and real-time WebSocket communication.

## Architecture

```
                    ┌─────────────────┐
                    │   User Browser  │
                    └─────────┬───────┘
                              │ :8081
                    ┌─────────▼───────┐
                    │   Nginx Proxy   │
                    │   :80 (8081)    │
                    └─────┬─────┬─────┘
                          │     │
               /vote/     │     │    /result/
                    ┌─────▼─┐ ┌─▼─────┐
                    │ Vote  │ │Result │
                    │Service│ │Service│
                    │Python │ │Node.js│
                    └───┬───┘ └───┬───┘
                        │         │
                        │         │ PostgreSQL
                   Redis│         │ queries
                    ┌───▼───┐ ┌───▼───┐
                    │ Redis │ │Postgre│
                    │ Queue │ │  SQL  │
                    └───┬───┘ └───▲───┘
                        │         │
                        │ consume │ store
                        │  votes  │ votes
                    ┌───▼─────────┘──┐
                    │ Worker Service │
                    │   .NET Core    │
                    └────────────────┘
```

### Components

#### Vote Service (Python + Flask)
- Frontend voting interface with cookie-based vote tracking
- Queues votes to Redis for asynchronous processing

#### Result Service (Node.js + Socket.IO)
- Real-time results dashboard with live WebSocket updates
- Displays vote tallies from PostgreSQL database

#### Worker Service (.NET Core)
- Background service that processes votes from Redis queue
- Persists validated votes to PostgreSQL

#### Redis
- Message queue for vote processing
- Session storage

#### PostgreSQL
- Persistent vote data storage

#### Nginx
- Reverse proxy providing unified access on port 8081
- Routes `/vote/` and `/result/` paths to respective services

### Data Flow

```
User Vote → Vote Service → Redis Queue → Worker Service → PostgreSQL → Result Service → Live Update
```

## Getting Started

### Prerequisites
- Docker & Docker Compose

### Start the Application

```bash
# Start all services
docker-compose up

# Or run in background
docker-compose up -d
```

### Access the Application

- **Vote Interface**: http://localhost:8081/vote/
- **Results Dashboard**: http://localhost:8081/result/
- **Database**: localhost:5432 (user: postgres, no password)
- **Redis**: localhost:6379

### Stop the Application

```bash
# Stop services
docker-compose down

# Stop and remove data volumes
docker-compose down -v
```

## Development

The development environment supports hot-reloading for the Python and Node.js services:

```bash
# View logs
docker-compose logs -f

# Rebuild a service after changes
docker-compose build vote
docker-compose build result
docker-compose build worker
```

Vote options can be customized by editing the environment variables in `docker-compose.yml`.
