---
applyTo: "**/collector-config.yaml"
---

# OpenTelemetry Collector Configuration Guidelines

When modifying the OpenTelemetry collector configuration, follow these critical patterns:

## Environment Variable Usage
- **ALWAYS** use `${GITHUB_ORG}` and `${GITHUB_REPO}` without default fallbacks
- **NEVER** use syntax like `${GITHUB_ORG:-default_value}` - it causes parsing errors
- Environment variables must be defined in docker-compose.yml environment section

## Repository Scoping (CRITICAL)
```yaml
# ✅ CORRECT - Scoped to specific repository
scrapers:
  scraper:
    github_org: ${GITHUB_ORG}
    search_query: "repo:${GITHUB_ORG}/${GITHUB_REPO}"

# ❌ WRONG - Scrapes entire organization (37+ repos)
scrapers:
  scraper:
    github_org: ${GITHUB_ORG}
```

## Spanmetrics Connector Dimensions
- **NEVER** change the dimension names without updating all Grafana dashboards
- Current dimensions: `workflow_step` and `step_status`
- These map to span.name and status.code respectively
- Namespace is "github_actions" - changing this breaks all dashboards

## Port Configuration
- Webhook endpoint: `0.0.0.0:9504` (must match docker-compose.yml)
- Metrics export: `0.0.0.0:9464` (for Prometheus scraping)
- Health endpoint: `/health` path
- Webhook path: `/events` path

## Authentication
- Use bearertokenauth extension for GitHub API
- Reference: `authenticator: bearertokenauth`
- Token source: `${GITHUB_TOKEN}` environment variable