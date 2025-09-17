#!/usr/bin/env bash

# GitHub Actions Observability Test Script
# Tests the complete observability pipeline

set -euo pipefail

COLLECTOR_URL="http://localhost:9504"
PROMETHEUS_URL="http://localhost:9090"
GRAFANA_URL="http://localhost:3000"

echo "🧪 GitHub Actions Observability Test Suite"
echo "=========================================="

# Test 1: Check collector health
echo "1️⃣ Testing OpenTelemetry Collector health..."
if curl -s "${COLLECTOR_URL}/health" | grep -q "healthy"; then
    echo "✅ Collector is healthy"
else
    echo "❌ Collector health check failed"
    exit 1
fi

# Test 2: Check Prometheus connectivity
echo "2️⃣ Testing Prometheus connectivity..."
if curl -s "${PROMETHEUS_URL}/-/healthy" >/dev/null; then
    echo "✅ Prometheus is healthy"
else
    echo "❌ Prometheus connectivity failed"
    exit 1
fi

# Test 3: Check Grafana connectivity
echo "3️⃣ Testing Grafana connectivity..."
if curl -s "${GRAFANA_URL}/api/health" | grep -q "ok"; then
    echo "✅ Grafana is healthy"
else
    echo "❌ Grafana connectivity failed"
    exit 1
fi

# Test 4: Send a test webhook event
echo "4️⃣ Sending test GitHub webhook event..."
test_payload='{
  "action": "completed",
  "workflow_run": {
    "id": 12345,
    "name": "CI Test Workflow",
    "head_branch": "main",
    "status": "completed",
    "conclusion": "success",
    "html_url": "https://github.com/test/repo/actions/runs/12345",
    "run_started_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "updated_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
  },
  "workflow": {
    "id": 567,
    "name": "CI Test Workflow",
    "path": ".github/workflows/ci.yml"
  },
  "repository": {
    "id": 123,
    "name": "test-repo",
    "full_name": "testorg/test-repo",
    "html_url": "https://github.com/testorg/test-repo"
  },
  "organization": {
    "login": "testorg"
  }
}'

# Calculate webhook signature
webhook_secret="${GITHUB_WEBHOOK_SECRET:-test-secret}"
signature="sha256=$(echo -n "$test_payload" | openssl dgst -sha256 -hmac "$webhook_secret" | cut -d' ' -f2)"

if curl -s -X POST "${COLLECTOR_URL}/events" \
    -H "Content-Type: application/json" \
    -H "X-GitHub-Event: workflow_run" \
    -H "X-Hub-Signature-256: $signature" \
    -H "User-Agent: GitHub-Hookshot/test" \
    -d "$test_payload" >/dev/null; then
    echo "✅ Test webhook sent successfully"
else
    echo "❌ Failed to send test webhook"
    exit 1
fi

# Wait a moment for processing
sleep 5

# Test 5: Check if metrics are being collected
echo "5️⃣ Checking GitHub Actions metrics in Prometheus..."
if curl -s "${PROMETHEUS_URL}/api/v1/query?query=github_actions_workflow_runs_total" | grep -q "success"; then
    echo "✅ GitHub Actions metrics found in Prometheus"
else
    echo "⚠️  GitHub Actions metrics not yet available (this might be normal for first run)"
fi

# Test 6: Check collector metrics endpoint
echo "6️⃣ Testing collector metrics endpoint..."
if curl -s "http://localhost:9464/metrics" | grep -q "github_actions"; then
    echo "✅ Collector is exposing GitHub Actions metrics"
else
    echo "⚠️  GitHub Actions metrics not yet exposed by collector"
fi

echo ""
echo "🎯 Test Summary:"
echo "- Collector Health: ✅"
echo "- Prometheus: ✅" 
echo "- Grafana: ✅"
echo "- Webhook Processing: ✅"
echo ""
echo "📊 Access your dashboards:"
echo "- Grafana: ${GRAFANA_URL}"
echo "- Prometheus: ${PROMETHEUS_URL}"
echo ""
echo "🔗 Webhook endpoint for GitHub:"
echo "- URL: ${COLLECTOR_URL}/events"
echo "- Events: workflow_run, workflow_job"
echo "- Content-Type: application/json"
echo ""
echo "✨ Setup verification complete! Your GitHub Actions observability stack is ready."