#!/usr/bin/env python3
"""
trigger_and_verify.py

This script:
- Checks or creates a GitHub webhook for a repository pointing to our Tunnel URL (/events)
- Triggers a GitHub Actions workflow dispatch
- Polls the OpenTelemetry Collector Prometheus endpoint for github_actions_workflow_runs_total metric
- Polls the Prometheus server to verify the metric is scraped
"""
import os
import sys
import time
import requests
from urllib.parse import urljoin

def load_env():
    from dotenv import load_dotenv
    load_dotenv()


def get_github_headers(token):
    return {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json'
    }


def ensure_webhook(owner, repo, tunnel_url, secret, token):
    hooks_url = f'https://api.github.com/repos/{owner}/{repo}/hooks'
    headers = get_github_headers(token)
    resp = requests.get(hooks_url, headers=headers)
    resp.raise_for_status()
    hooks = resp.json()
    target_url = tunnel_url.rstrip('/') + '/events'
    for hook in hooks:
        cfg = hook.get('config', {})
        if cfg.get('url') == target_url:
            print(f"Found existing webhook (id={hook['id']}) pointing to {target_url}")
            return
    print(f"Creating new webhook for {owner}/{repo} -> {target_url}")
    data = {
        'name': 'web',
        'active': True,
        'events': ['workflow_runs'],
        'config': {
            'url': target_url,
            'content_type': 'json',
            'secret': secret
        }
    }
    create_resp = requests.post(hooks_url, headers=headers, json=data)
    create_resp.raise_for_status()
    print(f"Webhook created: {create_resp.json()['id']}")


def get_workflow_id(owner, repo, workflow_name, token):
    url = f'https://api.github.com/repos/{owner}/{repo}/actions/workflows'
    r = requests.get(url, headers=get_github_headers(token))
    r.raise_for_status()
    workflows = r.json().get('workflows', [])
    for wf in workflows:
        if wf.get('name') == workflow_name or wf.get('path').endswith(workflow_name):
            return wf['id']
    raise ValueError(f"Workflow '{workflow_name}' not found in {owner}/{repo}")


def trigger_workflow(owner, repo, workflow_id, ref, inputs, token):
    url = f'https://api.github.com/repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches'
    data = {'ref': ref}
    if inputs:
        data['inputs'] = inputs
    r = requests.post(url, headers=get_github_headers(token), json=data)
    if r.status_code == 204:
        print('Workflow dispatch triggered')
    else:
        r.raise_for_status()


def poll_collector_metric(threshold=1, timeout=60):
    url = 'http://localhost:9464/metrics'
    start = time.time()
    while time.time() - start < timeout:
        try:
            r = requests.get(url)
            r.raise_for_status()
            if 'github_actions_workflow_runs_total' in r.text:
                # parse simple count
                for line in r.text.splitlines():
                    if line.startswith('github_actions_workflow_runs_total'):
                        val = float(line.split()[-1])
                        print(f"Collector metric value: {val}")
                        if val >= threshold:
                            return True
        except Exception:
            pass
        time.sleep(5)
    return False


def poll_prometheus(query, prometheus_url='http://localhost:9090', timeout=60):
    url = f'{prometheus_url}/api/v1/query'
    start = time.time()
    while time.time() - start < timeout:
        try:
            r = requests.get(url, params={'query': query})
            r.raise_for_status()
            data = r.json().get('data', {}).get('result', [])
            if data and float(data[0]['value'][1]) > 0:
                print(f"Prometheus metric '{query}' value: {data[0]['value'][1]}")
                return True
        except Exception as e:
            pass
        time.sleep(5)
    return False


def main():
    if len(sys.argv) < 2:
        print("Usage: trigger_and_verify.py <workflow_name>")
        sys.exit(1)
    workflow_name = sys.argv[1]
    load_env()
    token = os.getenv('GITHUB_TOKEN')
    secret = os.getenv('GITHUB_WEBHOOK_SECRET')
    tunnel_url = os.getenv('TUNNEL_URL') or os.getenv('GITHUB_WEBHOOK_URL')
    owner = 'vipulgupta2048'
    repo = 'vanilla'
    ref = os.getenv('GITHUB_REF', 'main')

    if not all([token, secret, tunnel_url]):
        print('Please set GITHUB_TOKEN, GITHUB_WEBHOOK_SECRET, and TUNNEL_URL in your environment')
        sys.exit(1)

    ensure_webhook(owner, repo, tunnel_url, secret, token)
    wf_id = get_workflow_id(owner, repo, workflow_name, token)
    trigger_workflow(owner, repo, wf_id, ref, {}, token)

    print('Waiting for collector metric...')
    if not poll_collector_metric():
        print('ERROR: collector did not record workflow metric in time')
        sys.exit(1)

    print('Waiting for Prometheus scrape...')
    if not poll_prometheus('github_actions_workflow_runs_total'):
        print('ERROR: Prometheus did not scrape metric in time')
        sys.exit(1)

    print('SUCCESS: end-to-end pipeline verified')

if __name__ == '__main__':
    main()
