---
applyTo: "**/grafana/dashboards/*.json"
---

# Grafana Dashboard Development Guidelines

When creating or modifying Grafana dashboards, follow these critical patterns to ensure compatibility:

## Metric Naming (CRITICAL)
```promql
# ✅ CORRECT - Use these exact metric names
github_actions_calls_total
github_actions_duration_seconds_sum
github_actions_duration_seconds_count
github_actions_duration_seconds_bucket

# ❌ WRONG - These don't exist in our setup
github_actions_traces_span_metrics_calls_total
github_actions_traces_span_metrics_duration_seconds_sum
```

## Label Dimensions
```promql
# ✅ CORRECT - Use our custom dimensions
{service_name, workflow_step, step_status}

# ❌ WRONG - Generic OpenTelemetry labels
{span_name, status_code}
```

## Status Values
```promql
# ✅ CORRECT - GitHub Actions status values
step_status="success"
step_status="failure" 
step_status="cancelled"

# ❌ WRONG - OpenTelemetry generic values
status_code="STATUS_CODE_OK"
status_code="STATUS_CODE_ERROR"
```

## Enterprise-Scale Queries
- **ALWAYS** use `topk()` for queries that could return many results
- **Example**: `topk(10, sum by (workflow_step) (github_actions_calls_total))`
- This prevents dashboard performance issues with hundreds of workflows

## Template Variables
```promql
# Service selector
label_values(github_actions_calls_total, service_name)

# Workflow step selector (with filtering)
label_values(github_actions_calls_total{service_name=~"$service"}, workflow_step)

# Status selector (with filtering)
label_values(github_actions_calls_total{service_name=~"$service",workflow_step=~"$workflow_step"}, step_status)
```

## Grafana Version Compatibility
- Use `byFrameRefID` not deprecated `byRefId` for transformations
- Set `refresh: "10s"` for real-time updates
- Use 24-hour time ranges: `"from": "now-24h", "to": "now"`

## Dashboard Structure
- Include descriptive panel titles and descriptions
- Use appropriate visualizations: timeseries for trends, stat for KPIs, table for details
- Configure proper units: `"unit": "s"` for seconds, `"unit": "percent"` for percentages
- Set meaningful color thresholds for status indicators