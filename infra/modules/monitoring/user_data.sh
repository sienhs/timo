#!/usr/bin/env bash
set -euo pipefail

dnf install -y docker python3
systemctl enable --now docker

install -d -m 0755 /opt/timo-monitoring/prometheus /opt/timo-monitoring/grafana/provisioning/datasources
install -d -m 0755 /var/lib/timo-monitoring/prometheus /var/lib/timo-monitoring/grafana
chown 65534:65534 /var/lib/timo-monitoring/prometheus
chown 472:472 /var/lib/timo-monitoring/grafana

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
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
GRAFANA

grafana_password=$(aws secretsmanager get-secret-value \
  --region '${aws_region}' \
  --secret-id '${grafana_secret_arn}' \
  --query SecretString \
  --output text | python3 -c 'import json, sys; print(json.load(sys.stdin)["GRAFANA_ADMIN_PASSWORD"])')

docker network inspect timo-monitoring >/dev/null 2>&1 || docker network create timo-monitoring
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
  '${grafana_image}'
