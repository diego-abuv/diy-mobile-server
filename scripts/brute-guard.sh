#!/data/data/com.termux/files/usr/bin/bash
set -o nounset
set -o pipefail

# ==============================================================================
# DIY MOBILE SERVER — BRUTE FORCE GUARD
# ==============================================================================

PROJECT_DIR="${HOME}/diy-mobile-server"
LOG_DIR="${PROJECT_DIR}/logs"
DATA_DIR="${PROJECT_DIR}/data"
ENV_FILE="${HOME}/.env"
FB_LOG="${LOG_DIR}/filebrowser.log"
BG_LOG="${LOG_DIR}/brute-guard.log"
TRIGGER_FILE="${DATA_DIR}/BRUTE_TRIGGERED"

THRESHOLD=5
WINDOW=120

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$BG_LOG"
}

# Se o filebrowser não está rodando, não há o que proteger
pkill -0 -f filebrowser 2>/dev/null || exit 0

# Se o túnel já está caído, não há acesso externo para proteger
pkill -0 -f cloudflared 2>/dev/null || exit 0

# Cooldown: se já foi acionado nos últimos 5 min, sai
if [[ -f "$TRIGGER_FILE" ]]; then
  trigger_ts=$(cat "$TRIGGER_FILE" 2>/dev/null || echo 0)
  now=$(date +%s)
  if [[ $((now - trigger_ts)) -lt 300 ]]; then
    exit 0
  fi
fi

# Conta tentativas 403 nos últimos WINDOW segundos
count=$(awk -v now=$(date +%s) -v window=$WINDOW '
/\/api\/login: 403/ {
  split($1, d, "/")
  split($2, t, ":")
  epoch = mktime(d[1] " " d[2] " " d[3] " " t[1] " " t[2] " " t[3])
  if (now - epoch <= window) count++
}
END { print count+0 }' "$FB_LOG" 2>/dev/null)

[[ "$count" -lt "$THRESHOLD" ]] && exit 0

log "ALERTA: $count tentativas de login em ${WINDOW}s"

# Sobe o alerta no Discord
source "$ENV_FILE" 2>/dev/null || true

if [[ -n "${DISCORD_WEBHOOK_URL:-}" ]]; then
  alert_payload=$(cat <<PAYLOAD
{
  "embeds": [{
    "title": "🚨 ALERTA DE SEGURANÇA",
    "description": "Brute force detectado no File Browser",
    "color": 15158332,
    "fields": [
      { "name": "Tentativas", "value": "$count em ${WINDOW}s" },
      { "name": "Ação", "value": "Servidor derrubado automaticamente" }
    ],
    "footer": { "text": "Termux NAS Security" }
  }]
}
PAYLOAD
)
  curl -s -o /dev/null --max-time 10 \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$alert_payload" \
    "${DISCORD_WEBHOOK_URL}"
  log "Alerta enviado ao Discord"
fi

# Registra cooldown
date +%s > "$TRIGGER_FILE"

# Corta acesso externo (mata só o túnel, mantém filebrowser local + crond)
pkill -f cloudflared 2>/dev/null
log "Túnel cloudflared derrubado por brute force"

# Acesso local (Wi-Fi) continua funcionando normalmente
log "Acesso local preservado (SSH + File Browser na rede local)"
