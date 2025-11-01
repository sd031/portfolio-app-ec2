# Docker Platform Compatibility Guide

## Overview

AWS EC2 instances use **x86_64/amd64** architecture. If you're building Docker images on a Mac (especially Apple Silicon M1/M2/M3) or ARM-based system, you need to ensure images are built for the correct platform.

## The Problem

### Mac Apple Silicon (M1/M2/M3)
- **Native architecture**: ARM64 (linux/arm64)
- **EC2 architecture**: x86_64 (linux/amd64)
- **Issue**: ARM images won't run on x86_64 EC2 instances

### Error Symptoms
```
exec /usr/local/bin/python: exec format error
```

or

```
standard_init_linux.go:228: exec user process caused: exec format error
```

## The Solution

Our `build-and-push.sh` script automatically handles this using **Docker Buildx**.

### How It Works

```bash
# Automatically builds for linux/amd64 regardless of host platform
docker buildx build --platform linux/amd64 --load -t image:tag .
```

## Verify Your Setup

### 1. Check Docker Version

```bash
docker --version
# Should be Docker 20.10+ or newer
```

### 2. Check Buildx Support

```bash
docker buildx version
# Should show buildx version
```

If not available:
```bash
# Update Docker Desktop to latest version
# Or install buildx plugin
```

### 3. Verify Platform Support

```bash
docker buildx ls
# Should show linux/amd64 in supported platforms
```

## Build Script Behavior

### With Buildx (Recommended)

```bash
./scripts/build-and-push.sh v1.0.0

# Output:
# [INFO] Docker buildx available - will build for linux/amd64 platform
# [STEP] Building frontend Docker image for linux/amd64...
# [INFO] Platform: linux/amd64 (compatible with AWS EC2)
```

### Without Buildx (Fallback)

```bash
./scripts/build-and-push.sh v1.0.0

# Output:
# [WARNING] Docker buildx not available. Using standard build (may have platform issues).
# [WARNING] For best results, update to Docker Desktop with buildx support.
# [WARNING] Platform: native (may not be compatible with AWS EC2 x86_64 instances)
```

## Manual Platform Build

If you need to build manually:

### Frontend

```bash
cd app/frontend

# With buildx (recommended)
docker buildx build --platform linux/amd64 -t my-image:tag .

# Without buildx (may not work on EC2)
docker build -t my-image:tag .
```

### Backend

```bash
cd app/backend

# With buildx (recommended)
docker buildx build --platform linux/amd64 -t my-image:tag .

# Without buildx (may not work on EC2)
docker build -t my-image:tag .
```

## Verify Image Platform

### Check Image Architecture

```bash
# Inspect local image
docker image inspect my-image:tag | grep Architecture

# Should show: "Architecture": "amd64"
```

### Check ECR Image

```bash
# Pull from ECR
docker pull <account-id>.dkr.ecr.us-west-2.amazonaws.com/3tier-web-app-frontend:v1.0.0

# Inspect
docker image inspect <account-id>.dkr.ecr.us-west-2.amazonaws.com/3tier-web-app-frontend:v1.0.0 | grep Architecture

# Should show: "Architecture": "amd64"
```

## Platform-Specific Issues

### Mac Apple Silicon (M1/M2/M3)

**Issue**: Building without `--platform` flag creates ARM images

**Solution**: Always use buildx with `--platform linux/amd64`

```bash
# ❌ Wrong - creates ARM image
docker build -t image:tag .

# ✅ Correct - creates x86_64 image
docker buildx build --platform linux/amd64 -t image:tag .
```

### Intel Mac

**Issue**: Usually no problem, but buildx ensures consistency

**Solution**: Use buildx for consistency across team

### Linux ARM (Raspberry Pi, etc.)

**Issue**: Same as Mac Apple Silicon

**Solution**: Use buildx with `--platform linux/amd64`

### Windows

**Issue**: Usually no problem with Docker Desktop

**Solution**: Ensure Docker Desktop is up to date

## Docker Desktop Settings

### Enable Buildx

1. Open Docker Desktop
2. Go to **Settings** → **Docker Engine**
3. Ensure experimental features are enabled:

```json
{
  "experimental": true,
  "features": {
    "buildkit": true
  }
}
```

4. Click **Apply & Restart**

### Create Buildx Builder

```bash
# Create a new builder instance
docker buildx create --name mybuilder --use

# Bootstrap the builder
docker buildx inspect --bootstrap

# Verify
docker buildx ls
```

## Troubleshooting

### Error: "docker buildx: command not found"

**Solution 1**: Update Docker Desktop
```bash
# Download latest from https://www.docker.com/products/docker-desktop
```

**Solution 2**: Install buildx manually
```bash
# For Mac
brew install docker-buildx

# For Linux
mkdir -p ~/.docker/cli-plugins
curl -L https://github.com/docker/buildx/releases/download/v0.11.2/buildx-v0.11.2.linux-amd64 -o ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx
```

### Error: "multiple platforms feature is currently not supported"

**Solution**: Create a new builder
```bash
docker buildx create --use
docker buildx inspect --bootstrap
```

### Error: "exec format error" on EC2

**Cause**: Image was built for wrong architecture

**Solution**: Rebuild with correct platform
```bash
./scripts/build-and-push.sh v1.0.1
# Ensure it shows: [INFO] Platform: linux/amd64 (compatible with AWS EC2)
```

### Slow Builds on Mac Apple Silicon

**Cause**: Emulating x86_64 on ARM is slower

**Solution**: This is expected. First build is slow, subsequent builds use cache.

```bash
# First build: ~5-10 minutes
# Subsequent builds: ~1-2 minutes (with cache)
```

### Error: "failed to solve with frontend dockerfile.v0"

**Solution**: Update Docker Desktop or use legacy builder
```bash
# Use legacy builder temporarily
DOCKER_BUILDKIT=0 docker build -t image:tag .
```

## Best Practices

### 1. Always Specify Platform

```bash
# In Dockerfile (optional but explicit)
FROM --platform=linux/amd64 python:3.11-slim
```

### 2. Use Multi-Stage Builds

```dockerfile
# Build stage
FROM --platform=linux/amd64 python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Runtime stage
FROM --platform=linux/amd64 python:3.11-slim
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY . .
CMD ["python", "app.py"]
```

### 3. Test Locally Before Pushing

```bash
# Build for amd64
docker buildx build --platform linux/amd64 --load -t test-image .

# Run locally (will be slower on ARM Mac)
docker run --rm -p 5000:5000 test-image

# Test
curl http://localhost:5000/health
```

### 4. Use Build Cache

```bash
# Buildx automatically caches layers
# Subsequent builds are much faster
docker buildx build --platform linux/amd64 --load -t image:v2 .
```

## Platform Matrix

| Host Platform | Native Arch | EC2 Arch | Buildx Required | Performance |
|---------------|-------------|----------|-----------------|-------------|
| Mac Intel | amd64 | amd64 | No* | Fast |
| Mac Apple Silicon | arm64 | amd64 | **Yes** | Moderate** |
| Linux x86_64 | amd64 | amd64 | No* | Fast |
| Linux ARM | arm64 | amd64 | **Yes** | Moderate** |
| Windows x86_64 | amd64 | amd64 | No* | Fast |

\* Recommended for consistency  
\*\* Emulation overhead

## Quick Reference

### Check Your Platform

```bash
# Host architecture
uname -m
# x86_64 = Intel/AMD
# arm64 = Apple Silicon

# Docker architecture
docker version --format '{{.Server.Arch}}'
```

### Build Commands

```bash
# Automatic (uses script)
./scripts/build-and-push.sh v1.0.0

# Manual with buildx
docker buildx build --platform linux/amd64 --load -t image:tag .

# Manual without buildx (not recommended for ARM hosts)
docker build -t image:tag .
```

### Verify Image

```bash
# Check architecture
docker image inspect image:tag --format '{{.Architecture}}'
# Should output: amd64

# Check OS
docker image inspect image:tag --format '{{.Os}}'
# Should output: linux
```

## Summary

✅ **Use the build script** - It handles everything automatically  
✅ **Ensure Docker Desktop is updated** - Get buildx support  
✅ **Verify platform** - Check build output shows `linux/amd64`  
✅ **Test before deploying** - Run containers locally  

The `build-and-push.sh` script automatically:
- Detects buildx availability
- Builds for linux/amd64 platform
- Falls back gracefully if buildx unavailable
- Shows platform info in output

**Just run**: `./scripts/build-and-push.sh v1.0.0` and you're good to go! 🚀
