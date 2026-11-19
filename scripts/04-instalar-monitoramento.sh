#!/usr/bin/env bash
set -euo pipefail
[[ "$EUID" -eq 0 ]] || { echo 'Execute com sudo bash'; exit 1; }
BASE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
install -d -m 755 /var/log/sereno-sp
install -m 755 "$BASE_DIR/scripts/03-monitoramento.sh" /usr/local/bin/sereno-monitoramento.sh
install -m 644 "$BASE_DIR/systemd/sereno-monitor.service" /etc/systemd/system/sereno-monitor.service
systemctl daemon-reload
systemctl enable --now sereno-monitor.service
systemctl is-active sereno-monitor.service
