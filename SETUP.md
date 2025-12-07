# OpenDIF Farajaland - Setup Guide

This guide will help you set up and run the OpenDIF Farajaland reference implementation on your local machine.

## Prerequisites

Before you begin, ensure you have the following installed:

### Required Software

- **Docker** 20.10+ and **Docker Compose** 2.0+
  - [Install Docker Desktop](https://www.docker.com/products/docker-desktop/)
  - Ensure Docker daemon is running before proceeding

- **Git** for version control
  - [Install Git](https://git-scm.com/downloads)

- **Python** 3.9+ (for RGD data source)
  - [Install Python](https://www.python.org/downloads/)
  - Recommended: Use `pyenv` or `conda` for version management

- **Ballerina** 2201.8.0+ (for DRP data source)
  - [Install Ballerina](https://ballerina.io/downloads/)

- **Node.js** 18+ (optional, for client applications)
  - [Install Node.js](https://nodejs.org/)

- **jq** (JSON processor, required by init script)
  - macOS: `brew install jq`
  - Ubuntu/Debian: `sudo apt-get install jq`
  - Windows: Download from [stedolan/jq](https://stedolan.github.io/jq/download/)

### System Requirements

- **RAM**: Minimum 4GB available (8GB recommended)
- **Disk Space**: At least 10GB free
- **Ports**: Ensure the following ports are available:
  - `2379, 2380` - etcd
  - `4000` - Orchestration Engine
  - `5432` - PostgreSQL
  - `8080` - RGD API
  - `8081` - Consent Engine
  - `8082` - Policy Decision Point
  - `9080, 9180` - API Gateway (APISIX)
  - `9090` - DRP API Adapter
  - `9443` - FUDI (WSO2 Identity Server)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/opendif-farajaland.git
cd opendif-farajaland
```

### 2. Make the Initialization Script Executable

```bash
chmod +x init.sh
```

### 3. Run the Initialization Script

The `init.sh` script automates the entire setup process:

```bash
./init.sh
```

**What the script does:**

1. ✅ Checks if Docker is running
2. ✅ Starts NDX infrastructure services via Docker Compose:
   - etcd (service registry)
   - APISIX API Gateway
   - PostgreSQL database
   - Orchestration Engine
   - Consent Engine
   - Policy Decision Point
   - FUDI/WSO2 Identity Server
3. ✅ Waits for services to be healthy
4. ✅ Configures FUDI (WSO2 Identity Server):
   - Creates OAuth2 applications for API Gateway
   - Creates SPA application for Consent Portal
   - Configures OIDC authentication
5. ✅ Registers API routes in APISIX Gateway
6. ✅ Starts member data source services:
   - RGD API (Python/FastAPI)
   - DRP API Adapter (Ballerina)

### 4. Verify the Setup

Once the script completes, you should see:

```
==========================================
All services started successfully!
==========================================

All services are running. Monitoring...
```

The script will continue running and monitoring services. Press `Ctrl+C` when you want to stop all services.

## Verifying Services

### Check Service Health

Open a new terminal window and run:

```bash
# Check Consent Engine
curl http://localhost:8081/health

# Check Policy Decision Point
curl http://localhost:8082/health

# Check Orchestration Engine
curl http://localhost:4000/health

# Check RGD API
curl http://localhost:8080/health

# Check DRP API Adapter
curl http://localhost:9090/health
```

### Check Docker Services

```bash
cd ndx
docker-compose ps
```

You should see all services in `Up` state.

### Check FUDI (WSO2 Identity Server)

Open your browser and navigate to:

```
https://localhost:9443/console
```

**Default credentials:**
- Username: `admin`
- Password: `admin`

You should see the WSO2 Identity Server console with two pre-configured applications:
- `NDX_API_GATEWAY` - M2M application for API Gateway
- `NDX_CONSENT_PORTAL` - SPA application for Consent Portal

## Testing the GraphQL API

### Basic Query (Without Authentication)

Try a simple GraphQL query to fetch person information:

```bash
curl -X POST http://localhost:9080/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ personInfo(nic: \"123456789V\") { fullName dateOfBirth address } }"
  }'
```

**Expected Response:**

```json
{
  "data": {
    "personInfo": {
      "fullName": "John Doe",
      "dateOfBirth": "1990-01-15",
      "address": "123 Main Street, Farajaland"
    }
  }
}
```

### Query with Consent Flow

For queries requiring consent (authenticated endpoints), you'll need to:

1. Obtain an access token from FUDI
2. Include the token in the request
3. Grant consent if prompted
4. Retry the request

See the [API Documentation](README.md#api-documentation) section in the main README for detailed examples.

## Manual Setup (Alternative)

If you prefer to set up services manually or the `init.sh` script fails, follow these steps:

### Step 1: Start NDX Infrastructure

```bash
cd ndx

# Start all NDX services
docker-compose up -d

# Wait for services to be ready (about 30 seconds)
sleep 30

# Check service status
docker-compose ps
```

### Step 2: Configure FUDI Applications

You'll need to manually create OAuth2 applications in WSO2 IS:

1. Access the WSO2 IS console at `https://localhost:9443/console`
2. Login with `admin`/`admin`
3. Create an M2M application for the API Gateway
4. Create an SPA application for the Consent Portal
5. Note down the client IDs and secrets

### Step 3: Register API Gateway Routes

Update the APISIX routes with your client credentials:

```bash
# Replace $CLIENT_ID and $CLIENT_SECRET with your values
curl --location --request PUT http://localhost:9180/apisix/admin/routes \
  --header "Content-Type: application/json" \
  --header "X-API-KEY: QuNGwapKysRvHfUtNkQFbUaGiiYeOcGo" \
  --data '{
    "uri": "/public/*",
    "methods": ["GET", "POST"],
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "orchestration-engine:4000": 1
      }
    },
    "plugins": {
      "openid-connect": {
        "discovery": "https://wso2is:9443/oauth2/token/.well-known/openid-configuration",
        "bearer_only": true,
        "client_id": "YOUR_CLIENT_ID",
        "client_secret": "YOUR_CLIENT_SECRET",
        "ssl_verify": false
      }
    },
    "id": "oe-endpoint"
  }'
```

### Step 4: Start Member Services

```bash
cd members

# Make the script executable
chmod +x run-member-services.sh

# Start all member services
./run-member-services.sh all
```

Or start services individually:

**RGD API:**
```bash
cd members/rgd/data-sources/rgd-api
python -m uvicorn main:app --port 8080
```

**DRP API Adapter:**
```bash
cd members/drp/data-sources/drp-api-adapter
bal run
```

## Troubleshooting

### Docker Issues

**Error: "Docker is not running"**
```bash
# Start Docker Desktop application
# Or start Docker daemon on Linux:
sudo systemctl start docker
```

**Error: "Port already in use"**
```bash
# Find and kill the process using the port (example for port 9080):
lsof -ti:9080 | xargs kill -9

# Or change the port in docker-compose.yml
```

### Service Health Check Failures

**PostgreSQL not ready:**
```bash
# Check PostgreSQL logs
cd ndx
docker-compose logs postgres

# Restart PostgreSQL
docker-compose restart postgres
```

**WSO2 Identity Server timeout:**
```bash
# Check WSO2 IS logs
docker-compose logs wso2is

# WSO2 IS takes 2-3 minutes to start, wait longer
# Or allocate more memory to Docker (increase to 4GB+)
```

### Python/Ballerina Issues

**Python dependencies missing:**
```bash
cd members/rgd/data-sources/rgd-api
pip install -r requirements.txt
```

**Ballerina build errors:**
```bash
cd members/drp/data-sources/drp-api-adapter
bal clean
bal build
```

### Script Permission Errors

```bash
# Make all shell scripts executable
chmod +x init.sh
chmod +x members/run-member-services.sh
chmod +x members/run-member-services.sh
chmod +x members/rgd/data-sources/rgd-api/start.sh
```

### jq Command Not Found

**macOS:**
```bash
brew install jq
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install jq
```

**Windows:**
Download from [stedolan/jq](https://stedolan.github.io/jq/download/) and add to PATH

## Stopping Services

### Using init.sh

If you started services with `./init.sh`, simply press `Ctrl+C` in the terminal where the script is running. The cleanup trap will automatically:

1. Stop all member services
2. Stop all Docker Compose services
3. Clean up resources

### Manual Cleanup

If you need to stop services manually:

```bash
# Stop Docker Compose services
cd ndx
docker-compose down

# Stop member services (if running in background)
# Find and kill the processes
ps aux | grep uvicorn  # RGD
ps aux | grep ballerina  # DRP

# Kill the processes
kill <PID>
```

### Complete Cleanup (Remove Data)

To remove all data and start fresh:

```bash
# Stop and remove all containers, networks, and volumes
cd ndx
docker-compose down -v

# Remove PostgreSQL data
rm -rf postgres-data/

# This will delete all database data and OAuth2 applications
# You'll need to run init.sh again to recreate everything
```

## Next Steps

Once your setup is complete and verified:

1. **Explore the GraphQL API**: Check out the [API Documentation](README.md#api-documentation)
2. **Understand the Architecture**: Read about the [Technical Architecture](README.md#technical-architecture)
3. **Try the Business Workflow**: Follow [The Business Workflow](README.md#the-business-workflow) guide
4. **Add New Data Sources**: Learn how to [Add a New Data Source](README.md#adding-a-new-data-source)
5. **Develop Client Applications**: Build applications that consume federated data

## Getting Help

If you encounter issues not covered in this guide:

1. Check the [main README](README.md) for additional documentation
2. Review service logs: `docker-compose logs <service-name>`
3. Open an issue on [GitHub Issues](https://github.com/your-org/opendif-farajaland/issues)
4. Ask in [GitHub Discussions](https://github.com/your-org/opendif-farajaland/discussions)

## Configuration Files

Key configuration files you may need to modify:

- `ndx/docker-compose.yml` - Infrastructure services configuration
- `ndx/fl-config.json` - Orchestration Engine data source configuration
- `ndx/schema.graphql` - Unified GraphQL schema
- `ndx/.env` - Environment variables for NDX services
- `ndx/config/apisix/conf.yaml` - API Gateway configuration
- `ndx/config/wso2is/deployment.toml` - FUDI/WSO2 IS configuration

## Advanced Configuration

### Enabling Additional Services

The `docker-compose.yml` includes optional services that are disabled by default. To enable them, uncomment the service definition in `ndx/docker-compose.yml` and restart:

```bash
cd ndx
docker-compose up -d
```

### Custom Environment Variables

Create or modify `ndx/.env`:

```bash
OE_CONFIG_PATH=./fl-config.json
OE_SCHEMA_PATH=./schema.graphql
ENVIRONMENT=local
DATABASE_URL=postgresql://exchange:exchange@postgres:5432/exchange_service
```

### Production Deployment

For production deployments:

1. Enable TLS/SSL for all services
2. Change default passwords and secrets
3. Use proper secrets management (e.g., HashiCorp Vault)
4. Enable WSO2 IS with proper configuration
5. Set up monitoring and logging
6. Configure proper backup strategies

See the [Security & Privacy](README.md#security--privacy) section in the main README for production recommendations.