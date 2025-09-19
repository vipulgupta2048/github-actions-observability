# GitHub Actions Observability Stack - Copilot Instructions

This is a **production-ready GitHub Actions observability solution** built with OpenTelemetry Collector, Prometheus, and Grafana. It provides complete visibility into CI/CD workflows with distributed tracing, rich metrics, and real-time dashboards.

## 🏗️ Project Architecture

**Core Stack:**
- **OpenTelemetry Collector v0.135.0** with GitHub receiver and spanmetrics connector
- **Prometheus** for metrics storage (30-day retention)  
- **Grafana** with 6 production-ready dashboards
- **Cloudflare Tunnel** for secure webhook exposure

**Data Flow:**
```
GitHub Actions → Webhooks → Cloudflare Tunnel → OTel Collector → Spanmetrics → Prometheus → Grafana
```

## 🛠️ Development Standards

### Environment Variables (CRITICAL)
```bash
# ALWAYS verify these are set - missing values cause rate limits and webhook failures
GITHUB_TOKEN=ghp_xxx          # GitHub PAT with repo, workflow, read:org scopes
GITHUB_WEBHOOK_SECRET=xxx     # 32+ char random string for webhook validation
GITHUB_ORG=your_org          # Target GitHub organization  
GITHUB_REPO=your_repo        # Target repository name
```

### Build & Run Commands
```bash
# Start full observability stack
docker compose up -d

# Check service health
docker compose ps
docker compose logs collector | grep -i github

# Health checks
curl http://localhost:9504/health     # Collector webhook health
curl http://localhost:9464/metrics    # Prometheus metrics endpoint
curl http://localhost:9090/targets    # Prometheus targets status

# Start secure tunnel for webhooks
./start-tunnel.sh

# Clean shutdown
docker compose down
```

### Service Architecture
- **Collector**: Ports 9504 (webhooks), 9464 (metrics export)
- **Prometheus**: Port 9090 (UI & API)
- **Grafana**: Port 3000 (dashboards) - admin/admin
- **Data Persistence**: Named volumes (otel_data, prometheus_data, grafana_data)

## 📊 Critical Metrics Schema

### Spanmetrics Connector Configuration
The heart of our metrics - ALL dashboard queries MUST match this:

```yaml
connectors:
  spanmetrics:
    namespace: "github_actions"    # Metric prefix
    dimensions:
      - name: workflow_step        # Custom dimension from span.name
        default: "unknown"
      - name: step_status         # Custom dimension from status.code
        default: "unknown"
```

### Generated Metrics (Use These Exact Names)
```promql
# ✅ CORRECT - What spanmetrics actually generates
github_actions_calls_total{service_name, workflow_step, step_status}
github_actions_duration_seconds_sum{service_name, workflow_step, step_status}  
github_actions_duration_seconds_count{service_name, workflow_step, step_status}
github_actions_duration_seconds_bucket{service_name, workflow_step, step_status, le}

# ❌ WRONG - Do NOT use these (common mistake)
github_actions_traces_span_metrics_calls_total
github_actions_traces_span_metrics_duration_seconds_sum
```

### Label Dimensions (Use Custom Dimensions)
```promql
# ✅ CORRECT - Our custom dimensions
workflow_step="Set up job", "Run tests", "Deploy"
step_status="success", "failure", "cancelled"

# ❌ WRONG - Generic OpenTelemetry labels  
span_name, status_code="STATUS_CODE_OK"
```

## 🎯 Dashboard Development Rules

### Metric Naming Validation
**ALWAYS verify metric names exist in Prometheus BEFORE creating dashboard queries:**
```bash
# Check available metrics
curl http://localhost:9090/api/v1/label/__name__/values | grep github_actions

# Verify custom dimensions
curl http://localhost:9090/api/v1/label/workflow_step/values
curl http://localhost:9090/api/v1/label/step_status/values
```

### Enterprise-Scale Query Patterns
```promql
# ✅ GOOD - Enterprise-ready with top-N limiting
topk(10, sum by (workflow_step) (github_actions_calls_total{step_status!="success"}))

# ❌ BAD - Will break with hundreds of workflows
sum by (workflow_step, service_name) (github_actions_calls_total)
```

### Template Variable Queries
```promql
# Service selector
label_values(github_actions_calls_total, service_name)

# Workflow step selector (filtered by service)  
label_values(github_actions_calls_total{service_name=~"$service"}, workflow_step)

# Status selector (filtered by service and step)
label_values(github_actions_calls_total{service_name=~"$service",workflow_step=~"$workflow_step"}, step_status)
```

## 🔧 Configuration Files

### Repository Scoping (collector-config.yaml)
```yaml
# ✅ CORRECT - Target specific repository only
scrapers:
  scraper:
    github_org: ${GITHUB_ORG}
    search_query: "repo:${GITHUB_ORG}/${GITHUB_REPO}"  # Prevents scraping all 37+ org repos

# ❌ WRONG - Scrapes entire organization
scrapers:
  scraper:
    github_org: ${GITHUB_ORG}  # No search_query filter
```

### Docker Environment Variables
ALL environment variables must be passed to collector container:
```yaml
collector:
  environment:
    GITHUB_TOKEN: ${GITHUB_TOKEN}
    GITHUB_WEBHOOK_SECRET: ${GITHUB_WEBHOOK_SECRET}
    GITHUB_ORG: ${GITHUB_ORG}          # Required for search_query
    GITHUB_REPO: ${GITHUB_REPO}        # Required for search_query
```

## 🚨 Common Mistakes to Avoid

### Dashboard Query Errors
1. **Wrong Metric Names**: Using `github_actions_traces_span_metrics_*` instead of `github_actions_*`
2. **Wrong Dimensions**: Using `span_name` instead of `workflow_step`
3. **Missing topk()**: Queries that return hundreds of results break Grafana
4. **Wrong Status Values**: Using `STATUS_CODE_OK` instead of `success`

### Configuration Errors  
1. **Missing Env Vars**: Causes `invalid uri: "GITHUB_ORG:-your_github_org"` errors
2. **No Repository Filtering**: Scrapes entire org instead of target repo
3. **Wrong Grafana Version**: Use `byFrameRefID` not deprecated `byRefId`

### Security Issues
1. **Hardcoded Secrets**: Never commit real tokens - use environment variables
2. **Missing .gitignore**: Ensure .env files are excluded from git
3. **Weak Webhook Secrets**: Use `openssl rand -hex 32` for strong secrets

## 📋 Quality Checklist

### Before Creating Dashboards
- [ ] Verify collector is running and healthy
- [ ] Test metric queries in Prometheus UI first
- [ ] Confirm custom dimensions exist and populate
- [ ] Use enterprise-scale query patterns (topk, rate, etc.)
- [ ] Test template variables return real data

### Before Modifying Configuration
- [ ] Read CONTEXT.md for historical context and lessons learned
- [ ] Verify environment variables are set correctly
- [ ] Check current spanmetrics configuration
- [ ] Test changes in development first
- [ ] Validate health endpoints after changes

### Production Readiness
- [ ] All secrets managed via environment variables
- [ ] Repository filtering configured to target specific repo
- [ ] Dashboard queries use correct metric names and dimensions
- [ ] Template variables functional with real data
- [ ] Health checks pass for all services

## 🎓 Key Learnings from Past Issues

1. **Metric Schema Changes**: Always check spanmetrics connector config before creating queries
2. **Environment Variables**: Missing GITHUB_ORG/GITHUB_REPO causes collector startup failures  
3. **Repository Scope**: Without search_query, collector scrapes entire GitHub organization
4. **Dashboard Compatibility**: Newer Grafana requires byFrameRefID not byRefId
5. **Scale Planning**: Use topk() queries to handle enterprise-scale deployments

## 🔗 Essential URLs

- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090 
- **Collector Health**: http://localhost:9504/health
- **Collector Metrics**: http://localhost:9464/metrics
- **Webhook Endpoint**: https://tunnel-url.trycloudflare.com/events

## 🎯 Success Indicators

Working system shows:
1. Green webhook status in GitHub repository settings
2. Collector logs show received webhook events  
3. Prometheus targets page shows collector as "UP"
4. Grafana dashboards display workflow trace data
5. Template variables populate with real repository data

---

**Trust these instructions** - they contain 8 major issue resolutions and prevent repeating critical mistakes. Only search for additional information if these instructions are incomplete or found to be in error.