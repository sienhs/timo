#!/usr/bin/env bash
set -euo pipefail

dnf install -y docker python3
systemctl enable --now docker

install -d -m 0755 /opt/timo-monitoring/prometheus /opt/timo-monitoring/grafana/provisioning/datasources /opt/timo-monitoring/grafana/provisioning/dashboards /opt/timo-monitoring/grafana/dashboards
install -d -m 0755 /var/lib/timo-monitoring/prometheus /var/lib/timo-monitoring/grafana
chown 65534:65534 /var/lib/timo-monitoring/prometheus
chown 472:472 /var/lib/timo-monitoring/grafana

install -d -m 0755 /opt/timo-monitoring/jaeger /var/lib/timo-monitoring/jaeger
chown 10001:10001 /var/lib/timo-monitoring/jaeger
cat >/opt/timo-monitoring/jaeger/config.yml <<'JAEGER'
service:
  extensions: [jaeger_storage, jaeger_query]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [jaeger_storage_exporter]
extensions:
  jaeger_query:
    http:
      endpoint: 0.0.0.0:16686
    storage:
      traces: local
  jaeger_storage:
    backends:
      local:
        badger:
          directories:
            keys: /data/keys
            values: /data/values
          ephemeral: false
          ttl:
            spans: 48h
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 384
    spike_limit_mib: 64
  batch:
exporters:
  jaeger_storage_exporter:
    trace_storage: local
JAEGER

cat >/opt/timo-monitoring/prometheus/prometheus.yml <<'PROMETHEUS'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: timo-backend
    metrics_path: /actuator/prometheus
    static_configs:
      - targets: ["${application_private_ip}:8080"]
PROMETHEUS

cat >/opt/timo-monitoring/grafana/provisioning/datasources/prometheus.yml <<'GRAFANA'
apiVersion: 1
deleteDatasources:
  - name: Prometheus
    orgId: 1
datasources:
  - name: Prometheus
    uid: prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
GRAFANA

cat >/opt/timo-monitoring/grafana/provisioning/dashboards/default.yml <<'DASHBOARD_PROVIDER'
apiVersion: 1
providers:
  - name: timo
    orgId: 1
    folder: Timo
    type: file
    disableDeletion: true
    editable: false
    options:
      path: /etc/grafana/dashboards
DASHBOARD_PROVIDER

cat >/opt/timo-monitoring/grafana/dashboards/timo-overview.json <<'DASHBOARD'
{
  "uid": "timo-overview",
  "title": "Timo Backend Overview",
  "tags": ["timo", "backend"],
  "timezone": "browser",
  "schemaVersion": 41,
  "version": 1,
  "refresh": "15s",
  "time": {"from": "now-30m", "to": "now"},
  "panels": [
    {
      "id": 1,
      "type": "stat",
      "title": "Backend target",
      "gridPos": {"x": 0, "y": 0, "w": 4, "h": 5},
      "datasource": {"type": "prometheus", "uid": "prometheus"},
      "targets": [{"refId": "A", "expr": "max(up{job=\"timo-backend\"})", "instant": true, "range": false}],
      "fieldConfig": {
        "defaults": {
          "mappings": [{"type": "value", "options": {"0": {"text": "DOWN", "color": "red"}, "1": {"text": "UP", "color": "green"}}}],
          "thresholds": {"mode": "absolute", "steps": [{"color": "red", "value": null}, {"color": "green", "value": 1}]}
        },
        "overrides": []
      }
    },
    {
      "id": 2,
      "type": "timeseries",
      "title": "Request rate",
      "gridPos": {"x": 4, "y": 0, "w": 10, "h": 8},
      "datasource": {"type": "prometheus", "uid": "prometheus"},
      "targets": [{"refId": "A", "expr": "sum(rate(http_server_requests_seconds_count{application=\"timo\"}[1m]))", "legendFormat": "requests/s"}],
      "fieldConfig": {"defaults": {"unit": "reqps", "decimals": 2}, "overrides": []}
    },
    {
      "id": 3,
      "type": "timeseries",
      "title": "p95 response time",
      "gridPos": {"x": 14, "y": 0, "w": 10, "h": 8},
      "datasource": {"type": "prometheus", "uid": "prometheus"},
      "targets": [{"refId": "A", "expr": "histogram_quantile(0.95, sum by (le) (rate(http_server_requests_seconds_bucket{application=\"timo\"}[5m])))", "legendFormat": "p95"}],
      "fieldConfig": {"defaults": {"unit": "s", "decimals": 3}, "overrides": []}
    },
    {
      "id": 4,
      "type": "timeseries",
      "title": "5xx error rate",
      "gridPos": {"x": 0, "y": 8, "w": 8, "h": 8},
      "datasource": {"type": "prometheus", "uid": "prometheus"},
      "targets": [{"refId": "A", "expr": "100 * sum(rate(http_server_requests_seconds_count{application=\"timo\",status=~\"5..\"}[5m])) / clamp_min(sum(rate(http_server_requests_seconds_count{application=\"timo\"}[5m])), 0.001)", "legendFormat": "5xx"}],
      "fieldConfig": {"defaults": {"unit": "percent", "decimals": 2, "min": 0}, "overrides": []}
    },
    {
      "id": 5,
      "type": "timeseries",
      "title": "JVM heap used",
      "gridPos": {"x": 8, "y": 8, "w": 8, "h": 8},
      "datasource": {"type": "prometheus", "uid": "prometheus"},
      "targets": [{"refId": "A", "expr": "100 * sum(jvm_memory_used_bytes{application=\"timo\",area=\"heap\"}) / sum(jvm_memory_max_bytes{application=\"timo\",area=\"heap\"})", "legendFormat": "heap used"}],
      "fieldConfig": {"defaults": {"unit": "percent", "decimals": 1, "min": 0, "max": 100}, "overrides": []}
    },
    {
      "id": 6,
      "type": "timeseries",
      "title": "DB connection pool",
      "gridPos": {"x": 16, "y": 8, "w": 8, "h": 8},
      "datasource": {"type": "prometheus", "uid": "prometheus"},
      "targets": [
        {"refId": "A", "expr": "hikaricp_connections_active{application=\"timo\"}", "legendFormat": "active"},
        {"refId": "B", "expr": "hikaricp_connections_pending{application=\"timo\"}", "legendFormat": "pending"},
        {"refId": "C", "expr": "hikaricp_connections_max{application=\"timo\"}", "legendFormat": "max"}
      ],
      "fieldConfig": {"defaults": {"unit": "short", "decimals": 0, "min": 0}, "overrides": []}
    }
  ]
}
DASHBOARD

grafana_password=$(aws secretsmanager get-secret-value \
  --region '${aws_region}' \
  --secret-id '${grafana_secret_arn}' \
  --query SecretString \
  --output text | python3 -c 'import json, sys; print(json.load(sys.stdin)["GRAFANA_ADMIN_PASSWORD"])')

docker network inspect timo-monitoring >/dev/null 2>&1 || docker network create timo-monitoring
docker pull '${jaeger_image}'
docker rm -f timo-jaeger >/dev/null 2>&1 || true
docker run -d --name timo-jaeger --restart unless-stopped \
  --network timo-monitoring \
  --user 10001:10001 \
  --memory 768m \
  --publish 127.0.0.1:16686:16686 \
  --publish 4318:4318 \
  --volume /opt/timo-monitoring/jaeger/config.yml:/etc/jaeger/config.yml:ro \
  --volume /var/lib/timo-monitoring/jaeger:/data \
  --log-driver json-file --log-opt max-size=10m --log-opt max-file=3 \
  '${jaeger_image}' --config /etc/jaeger/config.yml
for attempt in {1..30}; do
  if curl --fail --silent http://127.0.0.1:16686/api/services >/dev/null; then
    break
  fi
  sleep 2
done
curl --fail --silent http://127.0.0.1:16686/api/services >/dev/null
docker rm -f timo-prometheus timo-grafana >/dev/null 2>&1 || true

docker run -d --name timo-prometheus --restart unless-stopped \
  --network timo-monitoring \
  --network-alias prometheus \
  --publish 127.0.0.1:9090:9090 \
  --volume /opt/timo-monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
  --volume /var/lib/timo-monitoring/prometheus:/prometheus \
  '${prometheus_image}' \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/prometheus \
  --storage.tsdb.retention.time=15d \
  --web.enable-lifecycle

docker run -d --name timo-grafana --restart unless-stopped \
  --network timo-monitoring \
  --publish 3000:3000 \
  --env GF_SECURITY_ADMIN_USER=admin \
  --env GF_SECURITY_ADMIN_PASSWORD="$grafana_password" \
  --env GF_USERS_ALLOW_SIGN_UP=false \
  --env GF_SERVER_DOMAIN='${grafana_domain}' \
  --env GF_SERVER_ROOT_URL='https://${grafana_domain}' \
  --volume /var/lib/timo-monitoring/grafana:/var/lib/grafana \
  --volume /opt/timo-monitoring/grafana/provisioning:/etc/grafana/provisioning:ro \
  --volume /opt/timo-monitoring/grafana/dashboards:/etc/grafana/dashboards:ro \
  '${grafana_image}'
