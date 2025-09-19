---
applyTo: "**/docker-compose.yml"
---

# Docker Compose Configuration Guidelines

When modifying the Docker Compose configuration, follow these patterns:

## Environment Variables (CRITICAL)
All required environment variables must be passed to the collector service:
```yaml
collector:
  environment:
    GITHUB_TOKEN: ${GITHUB_TOKEN}           # Required - GitHub PAT
    GITHUB_WEBHOOK_SECRET: ${GITHUB_WEBHOOK_SECRET}  # Required - Webhook validation
    GITHUB_ORG: ${GITHUB_ORG}              # Required - Target organization
    GITHUB_REPO: ${GITHUB_REPO}            # Required - Target repository
```

## Service Dependencies
Maintain the correct dependency chain:
```yaml
# Correct dependency order
grafana:
  depends_on:
    - prometheus
    - collector

prometheus:
  depends_on:
    - collector
```

## Port Mappings
- **Collector**: `9504:9504` (webhooks), `9464:9464` (metrics)
- **Prometheus**: `9090:9090` (UI and API)
- **Grafana**: `3000:3000` (dashboards)

## Volume Mounts
- **Configuration**: Bind mounts for config files (read-only)
- **Data**: Named volumes for persistent storage
- **Grafana**: Both provisioning (config) and data volumes required

## Image Versions
- Use `latest` tags for development
- Consider pinning versions for production deployments
- OpenTelemetry Collector: `otel/opentelemetry-collector-contrib:latest`

## Network Configuration
- All services must be on the same network: `observability`
- Use bridge driver for internal communication
- No external network access required except for GitHub API calls