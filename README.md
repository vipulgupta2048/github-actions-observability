# GitHub Actions Observability with OpenTelemetry

Complete observability solution for GitHub Actions workflows using OpenTelemetry Collector, Prometheus, and Grafana. Monitor your CI/CD pipelines with distributed tracing, rich metrics, and real-time dashboards.

## 🎯 What You Get

- **📊 Complete Metrics**: Workflow execution rates, durations, success/failure rates
- **🔍 Distributed Traces**: Every workflow run as a detailed trace with job and step spans  
- **📈 Rich Dashboards**: 6 pre-built Grafana dashboards for different analysis needs
- **⚡ Real-time Data**: Live updates via GitHub webhooks with <15s latency
- **🔄 VCS Insights**: Pull request metrics, code change analysis, merge times
- **❌ Failure Analysis**: Identify problematic workflows, steps, and patterns


## Architecture

```mermaid
flowchart TD
    %% GitHub Source
    GH["🏠 GitHub Repository<br/><b>Actions Triggered</b>"]
    
    %% Webhook Flow
    GH -->|"workflow_run<br/>workflow_job events"| WH["📡 GitHub Webhook<br/><b>POST /events</b>"]
    WH -->|"HTTPS POST<br/>JSON payload"| CF["🔒 Cloudflare Tunnel<br/><b>Secure Proxy</b>"]
    
    %% Collector Entry Point
    CF -->|"Forward to<br/>localhost:9504"| COLLECTOR
    
    %% Main Processing Engine
    subgraph COLLECTOR ["🔄 OpenTelemetry Collector"]
        direction LR
        GHR["🎯 GitHub Receiver<br/>Port 9504"] 
        PIPELINE["⚙️ Processing Pipeline<br/>Resource → Attributes → Batch → Span Metrics"]
        PE["📈 Prometheus Exporter<br/>Port 9464"]
        
        GHR --> PIPELINE --> PE
    end
    
    %% Parallel API Data Source
    subgraph API ["🌐 GitHub API Scraping"]
        direction TB
        AUTH["🔐 Bearer Token Auth<br/>GitHub PAT"]
        SCRAPER["🔍 GitHub Scraper<br/>REST/GraphQL API"]
        VCS["📊 VCS Metrics<br/>Repos • PRs • Changes"]
        
        AUTH --> SCRAPER --> VCS
    end
    
    %% Connect API to Collector
    VCS -.->|"Additional<br/>metrics"| PE
    
    %% Data Storage
    PE -->|"Scrape metrics<br/>:9464/metrics"| PROM["⚡ Prometheus<br/><b>Time-Series Database</b><br/>30-day retention"]
    
    %% Visualization Layer
    PROM -->|"PromQL<br/>queries"| GRAFANA
    
    subgraph GRAFANA ["📈 Grafana Dashboards"]
        direction LR
        D1["📊 Overview"] --- D2["💚 Health"] --- D3["📋 Metrics"] --- D4["🏆 Performance"]
    end
    
    %% User Access
    USER["👤 User Browser<br/><b>localhost:3000</b>"] --> GRAFANA
    
    %% Enhanced Styling
    classDef source fill:#24292e,stroke:#f9826c,stroke-width:3px,color:#fff
    classDef webhook fill:#f38020,stroke:#fff,stroke-width:2px,color:#fff
    classDef collector fill:#326ce5,stroke:#fff,stroke-width:2px,color:#fff
    classDef storage fill:#e6522c,stroke:#fff,stroke-width:2px,color:#fff
    classDef dashboard fill:#f46800,stroke:#fff,stroke-width:2px,color:#fff
    classDef user fill:#00d924,stroke:#fff,stroke-width:3px,color:#fff
    
    class GH source
    class WH,CF webhook
    class GHR,PIPELINE,PE,AUTH,SCRAPER,VCS collector
    class PROM storage
    class D1,D2,D3,D4 dashboard
    class USER user
```
## 📋 Prerequisites

### Required Software
- **Docker Desktop**: Version 4.0+ with Docker Compose
- **Cloudflared**: For secure webhook tunneling
  ```bash
  # macOS (Homebrew)
  brew install cloudflare/cloudflare/cloudflared
  
  # Other platforms: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
  ```

### GitHub Requirements
- **Repository**: A GitHub repository where you want to monitor workflows
- **Personal Access Token**: With these scopes:
  - `repo` (Full read repository access)
  - `workflow` (Read GitHub Action workflows)
  - `read:org` (Read organization membership)
- **Webhook Secret**: A secure random string (we'll generate this)

### System Requirements
- **RAM**: 4GB minimum (8GB recommended)
- **Disk**: 10GB free space for metrics storage
- **Network**: Stable internet for GitHub API and tunnel

## 🚀 Complete Setup Guide

### Step 1: Clone and Prepare

```bash
# Clone this repository
git clone <your-repo-url>
cd otel-official

# Make scripts executable
chmod +x start-tunnel.sh
```

### Step 2: Create GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Select scopes: `repo`, `workflow`, `read:org`
4. Copy the token (you won't see it again!)

### Step 3: Configure Environment

```bash
# Generate a secure webhook secret
openssl rand -hex 32

# Create environment file
cat > .env << EOF
# GitHub Personal Access Token (with repo, workflow, read:org scopes)
GITHUB_TOKEN=ghp_your_token_here

# Webhook secret for validating GitHub requests (use output from openssl command above)
GITHUB_WEBHOOK_SECRET=your_generated_secret_here
EOF
```

### Step 4: Start the Observability Stack

```bash
# Start all services (Collector, Prometheus, Grafana)
docker compose up -d

# Check all services are healthy
docker compose ps
```

Expected output:
```
NAME                    STATUS
otel-official-collector-1    Up 2 seconds
otel-official-grafana-1      Up 2 seconds  
otel-official-prometheus-1   Up 2 seconds
```

### Step 5: Create Secure Tunnel

```bash
# Start the Cloudflare tunnel
./start-tunnel.sh
```

This will output something like:
```
🚀 Starting Cloudflare Tunnel for GitHub Webhooks
==================================================

✅ Tunnel created: https://abc-def-123.trycloudflare.com

🔗 GitHub Webhook Configuration:
   URL: https://abc-def-123.trycloudflare.com/events
   Content-Type: application/json
   Secret: (use GITHUB_WEBHOOK_SECRET from .env)
   Events: ✅ Workflow runs, ✅ Workflow jobs

⚡ Collector Health: http://localhost:9504/health
📊 Grafana: http://localhost:3000 (admin/admin)
```

**Keep this terminal open!** The tunnel only works while this script is running.

### Step 6: Configure GitHub Webhook

1. Go to your GitHub repository you want to track
2. Navigate to **Settings** → **Webhooks** 
3. Click **Add webhook**
4. Configure:
   - **Payload URL**: `https://your-tunnel-url.trycloudflare.com/events`
   - **Content type**: `application/json`
   - **Secret**: Paste your `GITHUB_WEBHOOK_SECRET` from `.env`
   - **Events selection**: Choose "Let me select individual events"
   - **Select events**: ✅ Workflow runs, ✅ Workflow jobs
5. Click **Add webhook**

### Step 7: Test the Setup

```bash
# Test webhook endpoint health
curl https://your-tunnel-url.trycloudflare.com/health

# Trigger a workflow in your repository
git push origin main  # or trigger manually from GitHub Actions tab
```

### Step 8: Access Dashboards

Open http://localhost:3000 in your browser:
- **Username**: `admin`
- **Password**: `admin` (change on first login)

Prometheus Dashbaord is available at http://localhost:9090

## 📊 Available Dashboards

1. **GitHub Actions Overview & Observability** - Executive summary and KPIs
2. **GitHub Actions - Workflow Exploration** - Detailed drill-down analysis  
3. **GitHub Actions - Workflow Analysis** - Scalable pattern analysis
4. **GitHub Actions - Repository Performance** - Strategic performance metrics
5. **GitHub Actions - Workflow Health Overview** - Health monitoring
6. **GitHub Actions - Complete Metrics** - Every available data point visualized

## 🔧 Configuration Details

### Collector Configuration (`collector-config.yaml`)

The OpenTelemetry Collector is configured with:
- **GitHub Receiver**: Webhook on port 9504, API scraping limited to your repository
- **Span Metrics Processor**: Generates RED metrics from traces
- **Prometheus Exporter**: Metrics on port 9464
- **Resource Processor**: Adds service metadata

### Key Metrics Generated

**From Webhooks (Traces → Span Metrics):**
```
github_actions_traces_span_metrics_calls_total{service_name="github-actions"}
github_actions_traces_span_metrics_duration_seconds{service_name="github-actions"}
```

**From GitHub API Scraping:**
```
github_actions_vcs_repository_count
github_actions_vcs_change_count{vcs_repository_name="your-repo"}
github_actions_vcs_change_duration_seconds{vcs_repository_name="your-repo"}
github_actions_vcs_ref_count{vcs_repository_name="your-repo"}
```

## 🛠️ Troubleshooting

### No Data in Dashboards

1. **Check webhook delivery**:
   - GitHub repo → Settings → Webhooks → Recent Deliveries
   - Look for 200 responses
   
2. **Verify collector is receiving data**:
   ```bash
   docker compose logs collector | grep "github"
   ```

3. **Test tunnel connectivity**:
   ```bash
   curl https://your-tunnel-url.trycloudflare.com/health
   ```

4. **Check Prometheus targets**: http://localhost:9090/targets
   - `otel-collector` should be "UP"

5. Takes a minute or two.

## 🎓 Understanding the Data Flow

```mermaid
sequenceDiagram
    participant GH as GitHub Actions
    participant WH as GitHub Webhook
    participant CF as Cloudflare Tunnel
    participant OC as OpenTelemetry Collector
    participant GS as GitHub Scraper
    participant PR as Prometheus
    participant GR as Grafana
    participant US as User

    %% Real-time Webhook Flow
    Note over GH: Workflow Triggered
    GH->>WH: POST workflow_run event
    WH->>CF: HTTPS request to tunnel
    CF->>OC: Forward to localhost:9504/events
    
    %% Collector Processing
    Note over OC: Event Processing Pipeline
    OC->>OC: Parse GitHub payload
    OC->>OC: Add resource metadata
    OC->>OC: Generate span metrics
    OC->>PR: Export metrics (:9464/metrics)
    
    %% Parallel API Scraping (every 60s)
    Note over GS: Periodic Scraping
    GS->>GH: GitHub API calls (authenticated)
    GH-->>GS: Repository & VCS data
    GS->>OC: VCS metrics
    OC->>PR: Export VCS metrics
    
    %% User Queries Dashboards
    Note over US: Dashboard Access
    US->>GR: Access dashboard
    GR->>PR: PromQL queries
    PR-->>GR: Metrics data
    GR-->>US: Rendered dashboard
    
    %% Health Checks
    US->>CF: GET /health
    CF->>OC: Health check
    OC-->>CF: {"status": "healthy"}
    CF-->>US: 200 OK
```

## 📦 Docker Services

| Service | Port | Purpose | Data Volume |
|---------|------|---------|-------------|
| **collector** | 9504, 9464 | OpenTelemetry data collection | `otel_data` |
| **prometheus** | 9090 | Metrics storage (30 days) | `prometheus_data` |
| **grafana** | 3000 | Dashboards and visualization | `grafana_data` |

## 🔗 Service Dependencies

```
grafana depends_on → prometheus depends_on → collector
```

All services are connected via the `observability` Docker network.


## 🎯 Success Indicators

After setup, you should see:

1. **GitHub Webhook**: ✅ Green checkmark in GitHub webhook settings
2. **Collector Logs**: Messages about receiving webhook events
3. **Prometheus Metrics**: Data visible at http://localhost:9090/graph
4. **Grafana Dashboards**: Populated charts with workflow data

## 📈 Sample Queries

Test these in Prometheus (http://localhost:9090):

```promql
# Workflow execution rate
rate(github_actions_traces_span_metrics_calls_total[5m])

# Repository activity 
github_actions_vcs_change_count{vcs_repository_name="your-repo"}

# Average workflow duration
rate(github_actions_traces_span_metrics_duration_seconds_sum[5m]) / 
rate(github_actions_traces_span_metrics_duration_seconds_count[5m])
```

## 🔧 Advanced Configuration

### Custom Repository Filtering
Edit `collector-config.yaml`:
```yaml
scrapers:
  scraper:
    github_org: your-org
    search_query: "repo:your-org/repo1 OR repo:your-org/repo2"
```

### Webhook Path Customization
```yaml
github:
  webhook:
    path: "/custom-webhook-path"
    health_path: "/custom-health"
```

### Metrics Retention
Edit `docker-compose.yml`:
```yaml
prometheus:
  command:
    - "--storage.tsdb.retention.time=90d"  # 90 days instead of 30
```

## 🛡️ Security Best Practices

### GitHub Token Security
- Use fine-grained Personal Access Tokens when possible
- Limit token scope to only required repositories
- Rotate tokens regularly (every 90 days)
- Store tokens in secure password managers

### Webhook Security
- Always use a strong, random webhook secret
- Regularly rotate webhook secrets
- Monitor webhook delivery logs for suspicious activity

### Infrastructure Security
- Use strong Grafana admin password
- Consider implementing reverse proxy with authentication
- Monitor collector logs for unauthorized access attempts
- Regularly update Docker images

