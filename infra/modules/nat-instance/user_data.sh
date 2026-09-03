#!/bin/bash
set -euxo pipefail

dnf install -y iptables-services

cat > /etc/sysctl.d/99-nat-ip-forwarding.conf <<'EOF'
net.ipv4.ip_forward=1
EOF

sysctl -p /etc/sysctl.d/99-nat-ip-forwarding.conf

systemctl enable iptables
systemctl start iptables

PRIMARY_IF="$(ip route show default | awk '/default/ {print $5; exit}')"

if [ -z "$PRIMARY_IF" ]; then
  echo "Could not determine the primary network interface" >&2
  exit 1
fi

# Make the rule idempotent in case the bootstrap script is executed again.
/sbin/iptables -t nat -C POSTROUTING \
  -s "${private_app_subnet_cidr}" \
  -o "$PRIMARY_IF" \
  -j MASQUERADE 2>/dev/null || \
/sbin/iptables -t nat -A POSTROUTING \
  -s "${private_app_subnet_cidr}" \
  -o "$PRIMARY_IF" \
  -j MASQUERADE

# Security Groups provide the network boundary; let Linux forward routed traffic.
/sbin/iptables -F FORWARD
/sbin/iptables -P FORWARD ACCEPT

service iptables save
