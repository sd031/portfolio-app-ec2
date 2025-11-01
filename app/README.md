# 3-Tier Application - Local Development with Docker

This directory contains the application code and Docker Compose configuration for local development and testing.

## Quick Start

### Prerequisites

- Docker Desktop installed
- Docker Compose v2.0+

### Start the Application

```bash
# From the app directory
docker-compose up -d
```

This will start:
- **MySQL Database** on port 3306
- **Backend API** on port 5001
- **Frontend Web App** on port 5000

### Access the Application

- **Frontend**: http://localhost:5000
- **Backend API**: http://localhost:5001
- **Database**: localhost:3306

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f frontend
docker-compose logs -f backend
docker-compose logs -f database
```

### Stop the Application

```bash
docker-compose down
```

### Stop and Remove Volumes (Clean Start)

```bash
docker-compose down -v
```

## Architecture

```
┌─────────────────┐
│   Frontend      │
│   Port: 5000    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Backend API   │
│   Port: 5001    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   MySQL DB      │
│   Port: 3306    │
└─────────────────┘
```

## Services

### Frontend
- **Technology**: Flask
- **Port**: 5000
- **Purpose**: Serves the portfolio web interface
- **Dockerfile**: `frontend/Dockerfile`

### Backend
- **Technology**: Flask + MySQL Connector
- **Port**: 5001
- **Purpose**: RESTful API for data operations
- **Dockerfile**: `backend/Dockerfile`

### Database
- **Technology**: MySQL 8.0
- **Port**: 3306
- **Purpose**: Data persistence
- **Initial Data**: Loaded from `init-db.sql`

## Development Workflow

### 1. Make Code Changes

Edit files in `frontend/` or `backend/` directories. Changes are automatically reflected due to volume mounts.

### 2. Rebuild After Dependency Changes

If you modify `requirements.txt`:

```bash
docker-compose build
docker-compose up -d
```

### 3. Access Database

```bash
# Using docker exec
docker exec -it 3tier-database mysql -u admin -ppassword123 appdb

# Or using MySQL client
mysql -h 127.0.0.1 -P 3306 -u admin -ppassword123 appdb
```

### 4. Run Database Queries

```sql
-- Show tables
SHOW TABLES;

-- View projects
SELECT * FROM projects;

-- View skills
SELECT * FROM skills;

-- View contact submissions
SELECT * FROM contacts;
```

## API Endpoints

### Backend API (http://localhost:5001)

- `GET /health` - Health check
- `GET /api/projects` - Get all projects
- `GET /api/skills` - Get all skills
- `POST /api/contact` - Submit contact form
- `GET /api/stats` - Get statistics

### Test API Endpoints

```bash
# Health check
curl http://localhost:5001/health

# Get projects
curl http://localhost:5001/api/projects

# Get skills
curl http://localhost:5001/api/skills

# Get stats
curl http://localhost:5001/api/stats

# Submit contact form
curl -X POST http://localhost:5001/api/contact \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com","message":"Test message"}'
```

## Troubleshooting

### Container Won't Start

```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs

# Restart specific service
docker-compose restart backend
```

### Database Connection Issues

```bash
# Check if database is healthy
docker-compose ps database

# View database logs
docker-compose logs database

# Verify database is accessible
docker exec -it 3tier-database mysqladmin ping -h localhost -u root -prootpassword
```

### Port Already in Use

If ports 5000, 5001, or 3306 are already in use, modify `docker-compose.yml`:

```yaml
ports:
  - "8000:5000"  # Change host port
```

### Reset Database

```bash
# Stop and remove volumes
docker-compose down -v

# Start fresh
docker-compose up -d
```

## Environment Variables

Create a `.env` file (copy from `.env.example`):

```bash
cp .env.example .env
```

Modify as needed for your local environment.

## Production Deployment

This Docker Compose setup is for **local development only**. For production:

1. Use the Terraform configuration in `../terraform/`
2. Deploy to AWS with proper security
3. Use managed services (RDS, ALB, etc.)
4. Enable HTTPS/SSL
5. Use secrets management

## File Structure

```
app/
├── docker-compose.yml      # Docker Compose configuration
├── init-db.sql            # Database initialization
├── .env.example           # Environment variables template
├── README.md              # This file
├── frontend/
│   ├── Dockerfile
│   ├── app.py
│   ├── requirements.txt
│   └── templates/
│       └── index.html
└── backend/
    ├── Dockerfile
    ├── app.py
    └── requirements.txt
```

## Useful Commands

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# Rebuild images
docker-compose build

# Restart a service
docker-compose restart backend

# Execute command in container
docker-compose exec backend bash

# View running containers
docker-compose ps

# Remove all containers and volumes
docker-compose down -v

# Pull latest images
docker-compose pull
```

## Performance Tips

1. **Use volumes for development**: Already configured for hot-reload
2. **Limit logs**: Use `docker-compose logs --tail=100`
3. **Clean up regularly**: Run `docker system prune` periodically
4. **Resource limits**: Add resource limits in docker-compose.yml if needed

## Security Notes

⚠️ **For Development Only**

- Default passwords are used (change for production)
- Database is exposed on host (restrict in production)
- Debug mode is enabled (disable in production)
- No SSL/TLS (required for production)

## Next Steps

1. **Customize the portfolio**: Edit `frontend/templates/index.html`
2. **Add features**: Extend backend API endpoints
3. **Test locally**: Verify everything works before AWS deployment
4. **Deploy to AWS**: Use Terraform configuration in `../terraform/`

## Support

For issues:
1. Check logs: `docker-compose logs`
2. Verify services are running: `docker-compose ps`
3. Check network: `docker network inspect app_app-network`
4. Review Docker documentation

---

**Happy Coding! 🐳**
