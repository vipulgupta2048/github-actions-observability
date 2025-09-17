# GitHub Actions Observability with OpenTelemetry

Complete observability solution for GitHub Actions workflows using OpenTelemetry Collector, Prometheus, and Grafana. Get deep insights into your CI/CD pipeline performance, failures, and bottlenecks with distributed tracing support.

## 🎯 Features

- **📊 Comprehensive Metrics**: Workflow runs, job durations, step timings, success rates
- **🔍 Distributed Traces**: See each workflow as a trace with jobs and steps as spans
- **📈 Rich Dashboards**: Pre-built Grafana dashboards for overview and detailed analysis
- **⚡ Real-time Monitoring**: Live updates via GitHub webhooks
- **🏃‍♂️ Runner Analytics**: Track runner utilization and queue times
- **❌ Failure Analysis**: Identify problematic workflows and steps

## Architecture

```
GitHub Actions → Webhook → OpenTelemetry Collector → {Prometheus, Tempo} → Grafana
```

## Components

- **OpenTelemetry Collector**: Production-grade collector with GitHub receiver for webhook processing
  - **Span Metrics Processor**: Automatically generates RED metrics (Rate, Errors, Duration) from trace data
  - **GitHub Receiver**: Processes webhooks and API data with minimal API impact
- **Prometheus**: Time-series metrics storage and querying with 30-day retention
- **Grafana Tempo**: Distributed tracing backend for workflow execution traces with 7-day retention
- **Grafana**: Comprehensive dashboards with 5 pre-configured views
- **Docker Compose**: Orchestrated production deployment with persistent volumes

## Production Features

- **Authentication**: Secure GitHub webhook validation with secrets
- **Memory Management**: Built-in memory limiters and batch processing
- **Monitoring**: Full stack monitoring including collector, Prometheus, and Tempo metrics
- **Scalability**: Configurable retention policies and resource limits
- **Security**: Environment-based secret management

## Quick Start

1. **Configure GitHub Integration**:
   ```bash
   cp .env.example .env
   # Edit .env with your GitHub token and webhook secret
   ```

2. **Deploy the Stack**:
   ```bash
   docker compose up -d
   ```

3. **Configure GitHub Repository Webhooks**:
   - URL: `http://your-server:9504/github`
   - Content Type: `application/json`
   - Secret: Use `GITHUB_WEBHOOK_SECRET` from `.env`
   - Events: Workflow runs, Workflow jobs, Pull requests

4. **Access Dashboards**:
   - Grafana: http://localhost:3000 (admin/admin)
   - Prometheus: http://localhost:9090
   - Tempo: http://localhost:3200

## Available Dashboards

1. **GitHub Actions Overview** - High-level KPIs and success metrics
2. **Performance Analysis** - Duration trends and performance bottlenecks
3. **Repository Health** - Repository statistics and activity tracking
4. **Infrastructure Monitoring** - Observability stack health
5. **Detailed Workflow Analysis** - Drill-down analysis with filtering

## Production Features

- **Span Metrics Generation**: Automatic conversion of trace data to metrics for dashboard compatibility
- **Persistent Storage**: Named Docker volumes ensure data survives container restarts
- **Data Retention**: Configurable retention policies (30 days for metrics, 7 days for traces)
- **Production-Ready Configuration**: Optimized for minimal API usage while maximizing data value

## Production Deployment

This stack includes persistent storage volumes for all components:

- **prometheus_data**: Stores 30 days of metrics data
- **tempo_data**: Stores 7 days of trace data  
- **grafana_data**: Stores dashboards, users, and configuration
- **otel_data**: Stores collector internal state and buffers

For production use, consider:

- ~~Configure persistent volumes for data retention~~ ✅ Already configured
- Set up reverse proxy with SSL/TLS termination
- Implement proper authentication and authorization
- Configure alerting rules and notification channels
- Scale Prometheus and Tempo for your workload
- Set up log aggregation for the collector

## Monitoring Capabilities

- **Real-time Metrics**: Workflow success rates, execution times, failure analysis
- **Distributed Tracing**: Complete workflow execution traces across jobs
- **Infrastructure Health**: Full stack monitoring and alerting
- **Performance Analytics**: P50/P90/P99 latency tracking
- **Repository Insights**: Activity trends and health scoring

### Prerequisites

- Docker Desktop installed and running
- `cloudflared` installed (for tunnel): `brew install cloudflared`

### Setup

1. **Clone/navigate to this directory**
   ```bash
   cd otel-official
   ```

2. **Configure environment variables**
   - Update `.env` file with your GitHub token and webhook secret
   - Or generate a new webhook secret:
     ```bash
     # Generate new secret (optional)
     openssl rand -hex 32
     ```

3. **Start the observability stack**
   ```bash
   ./start-stack.sh
   ```

4. **Start the webhook tunnel**
   ```bash
   ./start-tunnel.sh
   ```

5. **Configure GitHub webhook**
   - Go to your repository settings → Webhooks
   - Add the tunnel URL from step 4 (e.g., `https://abc123.trycloudflare.com/github`)
   - Set Content-Type: `application/json`
   - Add your webhook secret from `.env`
   - Select events: ✅ Workflow runs, ✅ Workflow jobs

### Access Points

- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Tempo**: http://localhost:3200

## Configuration Files

- `collector-config.yaml`: OpenTelemetry Collector configuration
- `docker-compose.yml`: Service definitions
- `prometheus.yml`: Prometheus scraping configuration
- `.env`: Environment variables (GitHub token, webhook secret)

## Generated Metrics

The GitHub receiver creates these metrics:

- `github_workflow_run_*`: Workflow run status, duration, timestamps
- `github_workflow_job_*`: Job status, duration, timestamps  
- `github_repository_*`: Repository stats (stars, forks, issues)

## Troubleshooting

### Docker Issues
```bash
# Check Docker status
docker ps

# Restart services
docker compose restart

# View logs
docker compose logs -f collector
```

### Webhook Issues
```bash
# Test webhook endpoint
curl -X POST http://localhost:9504/github

# Check collector logs
docker compose logs -f collector
```

### No Data in Grafana
1. Verify webhook is configured correctly in GitHub
2. Trigger a GitHub Action to generate events
3. Check Prometheus targets: http://localhost:9090/targets
4. Verify collector is receiving webhooks in logs

## Environment Variables

Required in `.env`:
- `GITHUB_TOKEN`: Personal access token with repo and workflow scopes
- `GITHUB_WEBHOOK_SECRET`: Secret for webhook validation

## Useful Commands

```bash
# Start everything
./start-stack.sh

# Create tunnel
./start-tunnel.sh

# Stop services
docker compose down

# View real-time logs
docker compose logs -f

# Restart specific service
docker compose restart collector
```
