#!/usr/bin/env bash
set -euo pipefail
# Reproduz infraestrutura e deployment. Exige arquivos em /home/ubuntu-server/:
#   sereno-migrations.sql e o diretorio publish-linux com Sereno.Api.dll.
# A senha do banco e solicitada interativamente; nao a envie ao GitHub.
[[ "$EUID" -eq 0 ]] || { echo 'Execute: sudo bash scripts/02-provisionar-aplicacao.sh'; exit 1; }
BASE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
LOG_DIR=/var/log/sereno-sp
install -d -m 755 "$LOG_DIR"
exec > >(tee -a "$LOG_DIR/provisionamento-aplicacao.log") 2>&1
echo "[$(date -Is)] Inicio de provisionamento"
apt-get update
apt-get install -y nginx postgresql postgresql-contrib aspnetcore-runtime-10.0 curl ca-certificates
systemctl enable --now nginx postgresql ssh
id serenoapp >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin serenoapp
install -d -m 755 /opt/sereno-sp
[[ -f /home/ubuntu-server/publish-linux/Sereno.Api.dll ]] || { echo 'Falta /home/ubuntu-server/publish-linux/Sereno.Api.dll'; exit 1; }
[[ -f /home/ubuntu-server/sereno-migrations.sql ]] || { echo 'Falta /home/ubuntu-server/sereno-migrations.sql'; exit 1; }
cp -a /home/ubuntu-server/publish-linux/. /opt/sereno-sp/
chown -R serenoapp:serenoapp /opt/sereno-sp
# Idempotencia na criacao do banco e role.
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='sereno_app'" | grep -q 1 || sudo -u postgres createuser sereno_app
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='sereno_sp'" | grep -q 1 || sudo -u postgres createdb -O sereno_app sereno_sp
# Faz o postgres conseguir ler o SQL independentemente de permissoes /home.
install -m 644 /home/ubuntu-server/sereno-migrations.sql /tmp/sereno-migrations.sql
sudo -u postgres psql -d sereno_sp -v ON_ERROR_STOP=1 -f /tmp/sereno-migrations.sql
sudo -u postgres psql -d sereno_sp -v ON_ERROR_STOP=1 <<'SQL'
GRANT USAGE, CREATE ON SCHEMA public TO sereno_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO sereno_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO sereno_app;
SQL
# Entrada sem eco. O password nao deve conter ponto-e-virgula ou quebra de linha.
install -d -m 700 /etc/sereno-sp
if [[ ! -f /etc/sereno-sp/sereno.env ]]; then
    read -rsp 'Senha NOVA do PostgreSQL sereno_app: ' DB_PASSWORD </dev/tty
    echo
    [[ -n "$DB_PASSWORD" && "$DB_PASSWORD" != *';'* ]] || { echo 'Senha vazia ou com ; nao suportada'; exit 1; }
    sudo -u postgres psql -v ON_ERROR_STOP=1 -v dbpass="$DB_PASSWORD" <<'SQL'
ALTER ROLE sereno_app PASSWORD :'dbpass';
SQL
    printf 'ConnectionStrings__DefaultConnection=Host=127.0.0.1;Port=5432;Database=sereno_sp;Username=sereno_app;Password=%s\n' "$DB_PASSWORD" > /etc/sereno-sp/sereno.env
    chmod 600 /etc/sereno-sp/sereno.env
    unset DB_PASSWORD
fi
install -m 644 "$BASE_DIR/systemd/sereno-api.service" /etc/systemd/system/sereno-api.service
install -m 644 "$BASE_DIR/nginx/sereno-sp.conf" /etc/nginx/sites-available/sereno-sp
ln -sfn /etc/nginx/sites-available/sereno-sp /etc/nginx/sites-enabled/default
nginx -t
systemctl daemon-reload
systemctl enable --now sereno-api.service
systemctl reload nginx
# Aguarda API iniciar antes de testar
for attempt in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:5000/health; then echo; break; fi
  sleep 2
done
curl -fsS http://127.0.0.1/health
echo
echo "[$(date -Is)] Provisionamento finalizado"
