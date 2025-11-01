# Docker Compose Quick Guide

## Local Development Setup

The `app/` directory now includes Docker Compose configuration for local development and testing before AWS deployment.

## Quick Start

```bash
cd app

# Start all services
docker-compose up -d

# Access the application
open http://localhost:5000
```

## What Gets Started

| Service | Port | URL |
|---------|------|-----|
| Frontend | 5000 | http://localhost:5000 |
| Backend API | 5001 | http://localhost:5001 |
| MySQL Database | 3306 | localhost:3306 |

## Common Commands

### Start Services

```bash
# Start in background
docker-compose up -d

# Start with logs
docker-compose up

# Start specific service
docker-compose up -d backend
```

### Stop Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f frontend
docker-compose logs -f backend
docker-compose logs -f database

# Last 50 lines
docker-compose logs --tail=50
```

### Rebuild After Changes

```bash
# Rebuild all services
docker-compose build

# Rebuild specific service
docker-compose build backend

# Rebuild and restart
docker-compose up -d --build
```

### Check Status

```bash
# List running containers
docker-compose ps

# View resource usage
docker stats
```

### Access Containers

```bash
# Execute bash in container
docker-compose exec backend bash
docker-compose exec frontend bash

# Run command in container
docker-compose exec backend python --version
```

### Database Access

```bash
# Access MySQL CLI
docker-compose exec database mysql -u admin -ppassword123 appdb

# Or from host
mysql -h 127.0.0.1 -P 3306 -u admin -ppassword123 appdb
```

## Testing API Endpoints

### Health Checks

```bash
# Backend health
curl http://localhost:5001/health

# Frontend health
curl http://localhost:5000/health
```

### API Endpoints

```bash
# Get projects
curl http://localhost:5001/api/projects | jq

# Get skills
curl http://localhost:5001/api/skills | jq

# Get statistics
curl http://localhost:5001/api/stats | jq

# Submit contact form
curl -X POST http://localhost:5001/api/contact \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "message": "Test message from Docker"
  }' | jq
```

## Development Workflow

### 1. Start Services

```bash
cd app
docker-compose up -d
```

### 2. Make Code Changes

Edit files in `app/frontend/` or `app/backend/`. Changes are automatically reflected due to volume mounts.

### 3. View Changes

Refresh your browser at http://localhost:5000

### 4. Check Logs

```bash
docker-compose logs -f backend
```

### 5. Stop When Done

```bash
docker-compose down
```

## Troubleshooting

### Port Already in Use

**Error**: `Bind for 0.0.0.0:5000 failed: port is already allocated`

**Solution**: Change port in `docker-compose.yml`:
```yaml
ports:
  - "8000:5000"  # Use port 8000 instead
```

### Database Connection Failed

**Check database is running**:
```bash
docker-compose ps database
```

**View database logs**:
```bash
docker-compose logs database
```

**Restart database**:
```bash
docker-compose restart database
```

### Container Won't Start

**View logs**:
```bash
docker-compose logs <service-name>
```

**Rebuild image**:
```bash
docker-compose build <service-name>
docker-compose up -d <service-name>
```

### Clean Start

```bash
# Stop everything
docker-compose down -v

# Remove all images
docker-compose down --rmi all

# Start fresh
docker-compose up -d --build
```

### Permission Issues

```bash
# Fix file permissions
sudo chown -R $USER:$USER .

# Or run with sudo
sudo docker-compose up -d
```

## Database Operations

### View Tables

```bash
docker-compose exec database mysql -u admin -ppassword123 appdb -e "SHOW TABLES;"
```

### Query Data

```bash
# View projects
docker-compose exec database mysql -u admin -ppassword123 appdb -e "SELECT * FROM projects;"

# View skills
docker-compose exec database mysql -u admin -ppassword123 appdb -e "SELECT * FROM skills;"

# View contacts
docker-compose exec database mysql -u admin -ppassword123 appdb -e "SELECT * FROM contacts;"
```

### Backup Database

```bash
docker-compose exec database mysqldump -u admin -ppassword123 appdb > backup.sql
```

### Restore Database

```bash
docker-compose exec -T database mysql -u admin -ppassword123 appdb < backup.sql
```

### Reset Database

```bash
# Stop and remove volumes
docker-compose down -v

# Start fresh (will run init-db.sql)
docker-compose up -d
```

## Performance Tips

### View Resource Usage

```bash
docker stats
```

### Limit Resources

Add to `docker-compose.yml`:
```yaml
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

### Clean Up Unused Resources

```bash
# Remove unused containers
docker container prune

# Remove unused images
docker image prune

# Remove unused volumes
docker volume prune

# Remove everything unused
docker system prune -a
```

## Environment Variables

### Create .env File

```bash
cd app
cp .env.example .env
```

### Edit Variables

```bash
# Edit .env
nano .env
```

### Use in docker-compose.yml

Variables in `.env` are automatically loaded.

## Network Debugging

### Inspect Network

```bash
docker network inspect app_app-network
```

### Test Connectivity

```bash
# From frontend to backend
docker-compose exec frontend curl http://backend:5001/health

# From backend to database
docker-compose exec backend nc -zv database 3306
```

## Production vs Development

| Feature | Development (Docker) | Production (AWS) |
|---------|---------------------|------------------|
| Database | MySQL container | RDS MySQL |
| Load Balancer | None | Application Load Balancer |
| Networking | Bridge network | VPC with subnets |
| Security | Basic | Security Groups, IAM |
| Scaling | Manual | Auto Scaling |
| SSL/TLS | No | Yes (ACM) |
| Monitoring | Logs | CloudWatch |

## Next Steps

### Local Development

1. ✅ Start services: `docker-compose up -d`
2. ✅ Test locally: http://localhost:5000
3. ✅ Make changes and iterate
4. ✅ Verify everything works

### AWS Deployment

1. 📋 Review Terraform configuration
2. 📋 Configure AWS credentials
3. 📋 Deploy to AWS: `cd terraform && terraform apply`
4. 📋 Access via ALB URL

## Useful Links

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker CLI Reference](https://docs.docker.com/engine/reference/commandline/cli/)
- [MySQL Docker Image](https://hub.docker.com/_/mysql)
- [Python Docker Image](https://hub.docker.com/_/python)

## File Structure

```
app/
├── docker-compose.yml      # Service orchestration
├── init-db.sql            # Database initialization
├── .env.example           # Environment template
├── README.md              # Detailed documentation
├── frontend/
│   ├── Dockerfile         # Frontend image
│   ├── app.py
│   ├── requirements.txt
│   └── templates/
└── backend/
    ├── Dockerfile         # Backend image
    ├── app.py
    └── requirements.txt
```

## Summary

✅ **Local Development**: Use Docker Compose  
✅ **Testing**: Test all features locally  
✅ **Production**: Deploy to AWS with Terraform  
✅ **Monitoring**: Use logs locally, CloudWatch in AWS  

---

**Happy Developing! 🐳**
