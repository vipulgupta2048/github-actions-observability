#!/usr/bin/env bash

# GitHub Webhook Tunnel Manager for OpenTelemetry Collector (Prometheus-only)
# - Exposes local collector on port 9504 via Cloudflare Tunnel
# - Prints the public URL to configure as GitHub Webhook
# - Aligns with current collector-config.yaml: path=/events, health_path=/health

set -euo pipefail

LOG_FILE="tunnel.log"
LOCAL_URL="http://localhost:9504"
WEBHOOK_PATH="/events"
HEALTH_PATH="/health"

BOLD="\033[1m"
RESET="\033[0m"

banner() {
  echo ""
  echo "🚀 ${BOLD}Starting Cloudflare Tunnel for GitHub Webhooks${RESET}"
  echo "=================================================="
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌ Required command '$1' not found." >&2
    if [ "$1" = "cloudflared" ]; then
      echo "👉 Install on macOS (Homebrew): brew install cloudflare/cloudflare/cloudflared" >&2
      echo "   Docs: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/" >&2
    fi
    exit 127
  fi
}

cleanup() {
  if [ -n "${TUNNEL_PID:-}" ] && kill -0 "${TUNNEL_PID}" 2>/dev/null; then
    echo ""
    echo "🛑 Stopping tunnel (PID: ${TUNNEL_PID})..."
    kill "${TUNNEL_PID}" 2>/dev/null || true
    sleep 2
  fi
  echo "👋 Goodbye!"
  exit 0
}

start_tunnel() {
  echo "🌀 Starting tunnel..."

  # Set up cleanup trap
  trap cleanup INT TERM EXIT

  # Start tunnel in background with nohup to prevent interruption
  nohup cloudflared tunnel --url "${LOCAL_URL}" >"${LOG_FILE}" 2>&1 &
  TUNNEL_PID=$!

  echo "⏳ Waiting for tunnel to initialize..."
  sleep 3

  # Try reading URL from log
  local url=""
  for attempt in $(seq 1 20); do
    if [ -f "${LOG_FILE}" ]; then
      url=$(grep -o 'https://[^[:space:]]*\.trycloudflare\.com' "${LOG_FILE}" | head -1 || true)
      if [ -n "${url}" ]; then
        break
      fi
    fi
    sleep 1
    echo "  Attempt ${attempt}/20..."
  done

  if [ -z "${url}" ]; then
    echo "❌ Failed to get tunnel URL. Check ${LOG_FILE} for errors." >&2
    echo "   Tip: If you see rate limits, wait a bit and re-run."
    kill ${TUNNEL_PID} >/dev/null 2>&1 || true
    exit 1
  fi

  echo ""
  echo "🎉 Tunnel is running!"
  echo "📍 Your GitHub Webhook Payload URL:"
  echo "   ${url}${WEBHOOK_PATH}"
  echo ""
  echo "🔧 Configure your GitHub webhook at your repository settings (Settings → Webhooks → Add webhook)."
  echo "   - Payload URL: ${url}${WEBHOOK_PATH}"
  echo "   - Content type: application/json"
  echo "   - Secret: Use GITHUB_WEBHOOK_SECRET from your .env (do not paste here)"
  echo "   - Events: ✅ Workflow runs, ✅ Workflow jobs (and any others you need)"
  echo ""
  echo "📋 Tunnel PID: ${TUNNEL_PID}"
  echo "📝 Logs: tail -f ${LOG_FILE}"
  echo "⏹️  Stop: kill ${TUNNEL_PID}"
  echo ""

  echo "🩺 Checking local collector health (${LOCAL_URL}${HEALTH_PATH})..."
  local health
  health=$(curl -s --max-time 5 "${LOCAL_URL}${HEALTH_PATH}" || true)
  if echo "${health}" | grep -qi healthy; then
    echo "✅ Collector health endpoint reports healthy"
  else
    echo "⚠️  Health endpoint response: ${health}"
  fi

  echo "🧪 Testing webhook endpoint accessibility (${url}${WEBHOOK_PATH})..."
  # Post minimal JSON; 200/400/500 are all acceptable as 'reachable' depending on receiver behavior
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X POST "${url}${WEBHOOK_PATH}" \
    -H "Content-Type: application/json" \
    -H "X-GitHub-Event: ping" \
    -d '{"zen":"test"}' || echo "timeout")

  case "${http_code}" in
    200|400|401|403|422|500)
      echo "✅ Webhook endpoint reachable (HTTP ${http_code})"
      ;;
    timeout)
      echo "❌ Request timed out; check connectivity/logs."
      ;;
    *)
      echo "⚠️  Webhook endpoint returned status: HTTP ${http_code}"
      ;;
  esac

  echo ""
  echo "🔄 Tunnel is running in background. To stop: kill ${TUNNEL_PID}"
  echo "   Keep this shell open or monitor logs with: tail -f ${LOG_FILE}"
  echo ""
  echo "🎯 ${BOLD}WEBHOOK URL (copy this for GitHub):${RESET}"
  echo "   ${url}${WEBHOOK_PATH}"
  echo ""

  # Keep script attached, printing a heartbeat with URL
  echo "⏰ Starting continuous monitoring... (URL will be logged every 15 seconds)"
  while kill -0 ${TUNNEL_PID} 2>/dev/null; do
    sleep 15
    echo "🔗 $(date '+%H:%M:%S'): Tunnel ACTIVE → ${url}${WEBHOOK_PATH}"
  done
  echo "🛑 Tunnel stopped."
}

main() {
  banner
  need_cmd curl
  need_cmd cloudflared
  start_tunnel
}

main "$@"
