#!/usr/bin/env bash
set -euo pipefail
# Provisionamento de rede seguro para VirtualBox NAT com DHCP.
# Não sobrescreve o Netplan nem define IP estático incompatível com NAT.
LOG_DIR=/var/log/sereno-sp
install -d -m 755 "$LOG_DIR"
exec > >(tee -a "$LOG_DIR/provisionamento-rede.log") 2>&1
[[ "$EUID" -eq 0 ]] || { echo 'Execute com sudo bash'; exit 1; }
echo "[$(date -Is)] Inicio do provisionamento de rede"
hostnamectl set-hostname sereno-server
apt-get update
apt-get install -y openssh-server curl ca-certificates dnsutils
systemctl enable --now ssh
IFACE=$(ip -o -4 route show default | awk 'NR==1 {print $5}')
[[ -n "$IFACE" ]] || { echo 'ERRO: gateway nao encontrado'; exit 1; }
echo "Interface: $IFACE"
ip -4 addr show "$IFACE"
ip -4 route show default
getent ahostsv4 archive.ubuntu.com | head -n 1 || true
curl --connect-timeout 10 -fsSI http://archive.ubuntu.com/ubuntu/ >/dev/null
systemctl is-active --quiet ssh
printf 'Rede, DNS, acesso ao repositorio Ubuntu e SSH: OK\n'
echo "[$(date -Is)] Fim do provisionamento de rede"
