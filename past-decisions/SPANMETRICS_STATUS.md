# SpanMetrics Investigation Status

## ✅ WORKING: SpanMetrics Processor
- **Confirmed**: SpanMetrics connector is generating metrics internally
- **Evidence**: Debug logs show `traces.span.metrics.duration` histogram with data points
- **Metrics Generated**: 
  - `traces.span.metrics.duration` (histogram)
  - `traces.span.metrics.calls` (counter/gauge)

## ✅ RESOLVED: Duplicate Label Conflicts  
- **Issue**: Prometheus exporter was failing with "duplicate label names in constant and variable labels"
- **Solution**: Disabled `resource_to_telemetry_conversion` and simplified spanmetrics dimensions
- **Status**: No more Prometheus export errors in logs

## ✅ RESOLVED: SpanMetrics Successfully Exported to Prometheus
- **Solution**: Fixed duplicate label conflicts by using custom dimension names
- **Available Metrics**: 
  - `github_actions_traces_span_metrics_duration_seconds` ✅ WORKING
  - `github_actions_traces_span_metrics_calls_total` ✅ WORKING
- **Current Status**: ✅ Visible in Prometheus scrape endpoint with real workflow data

## ⚠️ LIMITATION: GitHub Webhook Attributes Not Available in Spans
- **Problem**: Spans contain basic OpenTelemetry attributes but no GitHub webhook context
- **Available Attributes**:
  - `service.name: "github-actions"`
  - `span.name: "Set up job"/"Send greeting"/"Complete job"`
  - `span.kind: "SPAN_KIND_SERVER"`
  - `status.code: "STATUS_CODE_OK"`
- **Missing Attributes**:
  - `cicd_pipeline_name` (workflow name)
  - `vcs_repository_name` (repository name)
  - `cicd_pipeline_run_task_status` (job status)
  - `cicd_pipeline_task_run_sender_login` (actor)
  - `vcs_ref_head` (branch/commit)

## � **ROOT CAUSE DISCOVERED - Multiple Issues**

### **Issue 1: Missing Environment Variables** 
- **GITHUB_TOKEN**: NOT SET ❌ (causing rate limits on API scraper)
- **GITHUB_WEBHOOK_SECRET**: NOT SET ❌ (webhook validation failing)
- **Rate Limit Evidence**: `API rate limit already exceeded for user ID 22801822`

### **Issue 2: Receiver Understanding** 
Based on research, there are **TWO different receivers**:
- **`github` receiver** (official, in collector-contrib): Only creates basic spans, NO webhook attributes
- **`githubactions` receiver** (proposed/development): Would include full webhook payload attributes

**We're using the `github` receiver which explains why webhook attributes like `cicd_pipeline_name`, `vcs_repository_name` are missing from spans!**

## 📊 CURRENT SPANMETRICS OUTPUT
```
Data point attributes:
     -> service.name: Str(github-actions)
     -> span.name: Str(Complete job)
     -> span.kind: Str(SPAN_KIND_SERVER)
     -> status.code: Str(STATUS_CODE_OK)
     -> workflow_name: Str(unknown)    # Should be workflow name
     -> repository_name: Str(unknown)  # Should be repo name
     -> status_code: Str(unknown)      # Should be success/failure
```

## 🔧 IMMEDIATE ACTIONS NEEDED
1. **Investigate GitHub Receiver Configuration**: Check if additional configuration needed for attribute enrichment
2. **Debug Prometheus Export**: Understand why internal metrics aren't exported
3. **Alternative Attribution**: Consider using resource attributes or webhook parsing

## ✅ WORKING VERIFICATION QUERIES
These queries now return real data:
```promql
# Workflow step success rate (using actual available attributes)
github_actions_traces_span_metrics_calls_total{status_code="STATUS_CODE_OK"}

# Duration by workflow step name (available attribute)
github_actions_traces_span_metrics_duration_seconds{span_name="Manual workflow"}

# All available workflow steps
github_actions_traces_span_metrics_calls_total{service_name="github-actions"}
```

## 📊 ACTUAL AVAILABLE DIMENSIONS
- ✅ **service_name**: "github-actions" 
- ✅ **span_name**: "Manual workflow", "Complete job", "Send greeting", "Set up job"
- ✅ **span_kind**: "SPAN_KIND_SERVER"
- ✅ **status_code**: "STATUS_CODE_OK"
- ❌ **NOT AVAILABLE**: repository_name, workflow_name, cicd_pipeline_name, etc.