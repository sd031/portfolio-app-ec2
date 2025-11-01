# Architecture Documentation

## System Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                                │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Application Load Balancer                      │
│                      (Public Subnets)                            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Frontend EC2 Instances                          │
│              (Flask App - Public Subnets)                        │
│                    Port 5000 (HTTP)                              │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Backend EC2 Instances                           │
│              (Flask API - Private Subnets)                       │
│                    Port 5001 (HTTP)                              │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    RDS MySQL Database                            │
│                  (Database Subnets)                              │
│                    Port 3306 (MySQL)                             │
└─────────────────────────────────────────────────────────────────┘
```

## Network Architecture

### VPC Design

**CIDR Block**: 10.0.0.0/16

#### Subnet Layout

| Subnet Type | AZ | CIDR | Purpose |
|-------------|-------|--------------|---------|
| Public-1 | us-east-1a | 10.0.1.0/24 | ALB, NAT GW, Frontend EC2 |
| Public-2 | us-east-1b | 10.0.2.0/24 | ALB, NAT GW, Frontend EC2 |
| Private-1 | us-east-1a | 10.0.11.0/24 | Backend EC2 |
| Private-2 | us-east-1b | 10.0.12.0/24 | Backend EC2 |
| Database-1 | us-east-1a | 10.0.21.0/24 | RDS Primary |
| Database-2 | us-east-1b | 10.0.22.0/24 | RDS Standby |

### Routing

#### Public Route Table
- **Destination**: 0.0.0.0/0
- **Target**: Internet Gateway
- **Associated Subnets**: Public-1, Public-2

#### Private Route Tables (per AZ)
- **Destination**: 0.0.0.0/0
- **Target**: NAT Gateway (in same AZ)
- **Associated Subnets**: Private-1, Private-2

#### Database Route Tables (per AZ)
- **Destination**: 0.0.0.0/0
- **Target**: NAT Gateway (in same AZ)
- **Associated Subnets**: Database-1, Database-2

## Security Architecture

### Security Groups

#### ALB Security Group
```
Inbound Rules:
- Port 80 (HTTP) from 0.0.0.0/0
- Port 443 (HTTPS) from 0.0.0.0/0

Outbound Rules:
- All traffic to 0.0.0.0/0
```

#### Frontend EC2 Security Group
```
Inbound Rules:
- Port 5000 from ALB Security Group
- Port 22 (SSH) from 0.0.0.0/0 (restrict in production)

Outbound Rules:
- All traffic to 0.0.0.0/0
```

#### Backend EC2 Security Group
```
Inbound Rules:
- Port 5001 from Frontend Security Group
- Port 22 (SSH) from Public Subnets

Outbound Rules:
- All traffic to 0.0.0.0/0
```

#### Database Security Group
```
Inbound Rules:
- Port 3306 (MySQL) from Backend Security Group

Outbound Rules:
- All traffic to 0.0.0.0/0
```

### IAM Architecture

#### EC2 Instance Role
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "ec2:DescribeVolumes",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    }
  ]
}
```

**Attached Policies**:
- AmazonSSMManagedInstanceCore (for Session Manager)

## Application Architecture

### Frontend Layer

**Technology Stack**:
- Flask 3.0.0
- Gunicorn (WSGI server)
- Requests library
- HTML/CSS/JavaScript

**Responsibilities**:
- Serve web UI (personal portfolio)
- Proxy API requests to backend
- Handle user interactions
- Display data from backend

**Endpoints**:
- `GET /` - Main portfolio page
- `GET /health` - Health check
- `GET /api/projects` - Proxy to backend
- `GET /api/skills` - Proxy to backend
- `POST /api/contact` - Proxy to backend
- `GET /api/stats` - Proxy to backend

**Configuration**:
- Port: 5000
- Workers: 2
- Timeout: 60 seconds

### Backend Layer

**Technology Stack**:
- Flask 3.0.0
- Flask-CORS
- Gunicorn (WSGI server)
- MySQL Connector Python

**Responsibilities**:
- RESTful API endpoints
- Database operations (CRUD)
- Business logic
- Data validation

**Endpoints**:
- `GET /health` - Health check with DB status
- `GET /api/projects` - Fetch projects from DB
- `GET /api/skills` - Fetch skills from DB
- `POST /api/contact` - Save contact form to DB
- `GET /api/stats` - Get portfolio statistics

**Configuration**:
- Port: 5001
- Workers: 2
- Timeout: 60 seconds

**Database Connection**:
- Host: RDS endpoint (from environment)
- Database: appdb
- User: admin (from environment)
- Password: Secure password (from environment)

### Database Layer

**Technology**: Amazon RDS MySQL 8.0

**Configuration**:
- Instance Class: db.t3.micro
- Storage: 20 GB (gp3)
- Encrypted: Yes
- Multi-AZ: No (enable for production)
- Backup Retention: 7 days

**Schema**:

```sql
-- Projects Table
CREATE TABLE projects (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    technologies VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Skills Table
CREATE TABLE skills (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Contacts Table
CREATE TABLE contacts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Load Balancing

### Application Load Balancer

**Configuration**:
- Type: Application Load Balancer
- Scheme: Internet-facing
- IP Address Type: IPv4
- Subnets: Public-1, Public-2

**Target Group**:
- Protocol: HTTP
- Port: 5000
- Health Check Path: /health
- Health Check Interval: 30 seconds
- Healthy Threshold: 2
- Unhealthy Threshold: 2
- Timeout: 5 seconds

**Listener**:
- Protocol: HTTP
- Port: 80
- Default Action: Forward to Frontend Target Group

## High Availability

### Multi-AZ Deployment

**Current Setup**:
- 2 Availability Zones (us-east-1a, us-east-1b)
- 2 Frontend EC2 instances (1 per AZ)
- 2 Backend EC2 instances (1 per AZ)
- 2 NAT Gateways (1 per AZ)
- RDS Single-AZ (upgrade to Multi-AZ for production)

**Failure Scenarios**:

1. **Single EC2 Instance Failure**
   - ALB automatically routes to healthy instance
   - No downtime

2. **Availability Zone Failure**
   - Traffic routes to healthy AZ
   - 50% capacity reduction
   - No data loss

3. **NAT Gateway Failure**
   - Only affects instances in same AZ
   - Other AZ continues operating

## Scalability

### Horizontal Scaling

**Frontend**:
- Add more EC2 instances to target group
- ALB distributes traffic automatically
- Stateless design allows easy scaling

**Backend**:
- Add more EC2 instances
- Update frontend to use multiple backend endpoints
- Consider implementing service discovery

**Database**:
- Implement read replicas for read-heavy workloads
- Use connection pooling
- Implement caching layer (ElastiCache)

### Vertical Scaling

- Upgrade instance types (t3.micro → t3.small → t3.medium)
- Increase RDS instance class
- Add more storage to RDS

## Performance Optimization

### Current Optimizations

1. **Application Level**
   - Gunicorn with multiple workers
   - Connection pooling to database
   - Efficient database queries

2. **Network Level**
   - Multi-AZ deployment reduces latency
   - ALB distributes load evenly
   - NAT Gateways provide high bandwidth

3. **Database Level**
   - Indexed primary keys
   - Optimized table structure
   - Regular maintenance windows

### Future Optimizations

1. **Caching**
   - Add ElastiCache (Redis)
   - Cache database queries
   - Implement CDN for static assets

2. **Auto Scaling**
   - CPU-based auto scaling
   - Schedule-based scaling
   - Target tracking policies

3. **Database**
   - Read replicas
   - Query optimization
   - Partitioning for large tables

## Monitoring and Logging

### CloudWatch Metrics

**EC2 Metrics**:
- CPU Utilization
- Network In/Out
- Disk Read/Write
- Status Checks

**RDS Metrics**:
- CPU Utilization
- Database Connections
- Free Storage Space
- Read/Write IOPS

**ALB Metrics**:
- Request Count
- Target Response Time
- HTTP 4xx/5xx Errors
- Healthy/Unhealthy Host Count

### Logging

**Application Logs**:
- Location: `/var/log/user-data.log`
- Service Logs: `journalctl -u frontend/backend.service`

**CloudWatch Logs**:
- RDS Error Logs
- RDS Slow Query Logs
- RDS General Logs

## Disaster Recovery

### Backup Strategy

**RDS Backups**:
- Automated daily backups
- Retention: 7 days
- Manual snapshots before major changes

**Recovery Time Objective (RTO)**: 1 hour
**Recovery Point Objective (RPO)**: 24 hours

### Recovery Procedures

1. **Database Failure**
   - Restore from latest automated backup
   - Point-in-time recovery available

2. **Complete Region Failure**
   - Deploy infrastructure in new region using Terraform
   - Restore database from snapshot
   - Update DNS records

## Cost Analysis

### Monthly Cost Breakdown

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| EC2 (Frontend) | 2 × t3.micro | $15 |
| EC2 (Backend) | 2 × t3.micro | $15 |
| RDS MySQL | db.t3.micro | $15 |
| ALB | Standard | $20 |
| NAT Gateway | 2 × Standard | $70 |
| Data Transfer | ~100 GB | $10 |
| **Total** | | **~$145** |

### Cost Optimization Strategies

1. **Reserved Instances**: Save 30-70% on EC2 and RDS
2. **Single NAT Gateway**: Save $35/month (reduce HA)
3. **Spot Instances**: Save up to 90% for non-critical workloads
4. **Right-sizing**: Monitor and adjust instance sizes

## Security Considerations

### Data Protection

1. **Encryption at Rest**
   - RDS storage encrypted
   - EBS volumes encrypted
   - S3 buckets encrypted (if used)

2. **Encryption in Transit**
   - HTTPS for external traffic (recommended)
   - SSL/TLS for database connections (recommended)

3. **Secrets Management**
   - Use AWS Secrets Manager for DB credentials
   - Rotate credentials regularly
   - No hardcoded secrets

### Network Security

1. **Defense in Depth**
   - Multiple security group layers
   - Private subnets for sensitive resources
   - Network ACLs (optional additional layer)

2. **Least Privilege**
   - Minimal security group rules
   - IAM roles with specific permissions
   - No public database access

### Compliance

- **GDPR**: Implement data retention policies
- **PCI-DSS**: If handling payments, additional controls needed
- **HIPAA**: If handling health data, additional controls needed

## Future Enhancements

### Short Term (1-3 months)

1. Implement Auto Scaling Groups
2. Add HTTPS with ACM certificate
3. Set up CloudWatch dashboards
4. Implement automated backups verification

### Medium Term (3-6 months)

1. Add ElastiCache for caching
2. Implement CI/CD pipeline
3. Add WAF for application protection
4. Multi-region deployment

### Long Term (6-12 months)

1. Migrate to containers (ECS/EKS)
2. Implement microservices architecture
3. Add API Gateway
4. Implement advanced monitoring (X-Ray)

## References

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [ALB Best Practices](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/best-practices.html)
