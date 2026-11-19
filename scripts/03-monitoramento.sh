#!/usr/bin/env bash
set -euo pipefail

CPU_LIMITE="${CPU_LIMITE:-80}"
MEMORIA_LIMITE="${MEMORIA_LIMITE:-85}"
DISCO_LIMITE="${DISCO_LIMITE:-90}"
INTERVALO="${INTERVALO:-30}"
LOG="/var/log/sereno-sp/monitoramento.log"

mkdir -p "$(dirname "$LOG")"

registrar() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1 | $2" | tee -a "$LOG"
}

monitorar() {
    read -r _ u n s i w irq sirq steal _ < /proc/stat
    total1=$((u+n+s+i+w+irq+sirq+steal))
    idle1=$((i+w))
    sleep 1
    read -r _ u n s i w irq sirq steal _ < /proc/stat
    total2=$((u+n+s+i+w+irq+sirq+steal))
    idle2=$((i+w))

    delta=$((total2-total1))
    cpu=0
    if (( delta > 0 )); then
        cpu=$((100*(delta-(idle2-idle1))/delta))
    fi

    memoria=$(free | awk '/^Mem:/ {printf "%.0f", 100*$3/$2}')
    disco=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')

    registrar INFO "CPU=${cpu}% MEMORIA=${memoria}% DISCO=${disco}%"

    if (( cpu >= CPU_LIMITE )); then
        registrar ALERTA "CPU acima do limite de ${CPU_LIMITE}%"
    fi
    if (( memoria >= MEMORIA_LIMITE )); then
        registrar ALERTA "Memoria acima do limite de ${MEMORIA_LIMITE}%"
    fi
    if (( disco >= DISCO_LIMITE )); then
        registrar ALERTA "Disco acima do limite de ${DISCO_LIMITE}%"
    fi
}

registrar INFO "Monitoramento Sereno SP iniciado"

if [[ "${1:-}" == "--once" ]]; then
    monitorar
    exit 0
fi

while true; do
    monitorar
    sleep "$INTERVALO"
done