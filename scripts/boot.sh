#!/data/data/com.termux/files/usr/bin/bash
set -o nounset
set -o pipefail

# ==============================================================================
# DIY MOBILE SERVER — BOOT SCRIPT
# ==============================================================================

PROJECT_DIR="${HOME}/diy-mobile-server"
LOG_DIR="${PROJECT_DIR}/logs"
DATA_DIR="${PROJECT_DIR}/data"

ENV_FILE="${HOME}/.env"
BOOT_LOG="${LOG_DIR}/boot.log"
CF_LOG="${LOG_DIR}/cloudflared.log"
FB_LOG="${LOG_DIR}/filebrowser.log"
URL_FILE="${DATA_DIR}/current_url.txt"
MSG_ID_FILE="${DATA_DIR}/msg_id.txt"
FB_DB="${DATA_DIR}/filebrowser.db"

LOCK_FILE="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/diy-boot.lock"

MAX_RETRIES=20
RETRY_DELAY=2

# ==============================================================================
# FUNÇÕES
# ==============================================================================

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$BOOT_LOG"
}

get_local_ip() {
  ip -4 addr show wlan0 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1
}

USER_CREATED=false

cleanup() {
  log "Encerrando processos antigos..."
  pkill -f filebrowser 2>/dev/null || true
  pkill -f cloudflared 2>/dev/null || true
  rm -f "$CF_LOG" "$FB_LOG"
}

send_short_notification() {
  local msg="🔄 **Túnel renovado** às $(date '+%H:%M:%S')"
  curl -s -o /dev/null --max-time 10 \
    -H "Content-Type: application/json" \
    -X POST \
    -d "{\"content\": \"$msg\"}" \
    "${DISCORD_WEBHOOK_URL}"
}

build_embed() {
  cat <<EMBED
{
  "embeds": [{
    "title": "🚀 Servidor NAS Online!",
    "description": "Túnel Cloudflare atualizado no Galaxy A14.",
    "color": 3066993,
    "fields": [
      { "name": "🔗 Link de Acesso", "value": "[Clique aqui]($URL)" },
      { "name": "📅 Última Atualização", "value": "$(date '+%d/%m/%Y %H:%M:%S')" }
    ],
    "footer": { "text": "Termux NAS Monitor" }
  }]
}
EMBED
}

patch_or_post_embed() {
  local msg_id=""
  [[ -f "$MSG_ID_FILE" ]] && msg_id=$(cat "$MSG_ID_FILE")

  local payload
  payload=$(build_embed)

  if [[ -n "$msg_id" ]]; then
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
      -H "Content-Type: application/json" \
      -X PATCH \
      -d "$payload" \
      "${DISCORD_WEBHOOK_URL}/messages/${msg_id}")

    if [[ "$status" == "200" ]]; then
      log "Embed canônico editado (PATCH 200)"
      send_short_notification
      return
    fi

    log "PATCH falhou (HTTP $status). Criando novo embed..."
  fi

  local response
  response=$(curl -s --max-time 15 \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$payload" \
    "${DISCORD_WEBHOOK_URL}?wait=true")

  local new_id
  new_id=$(echo "$response" | grep -o '"id": *"[0-9]*"' | head -1 | sed 's/[^0-9]//g')

  if [[ -n "$new_id" ]]; then
    echo "$new_id" > "$MSG_ID_FILE"
    log "Novo embed criado (POST). MSG_ID=$new_id"
  else
    log "Falha ao extrair ID do novo embed"
  fi
}

# ==============================================================================
# EXECUÇÃO
# ==============================================================================

if [[ -f "$LOCK_FILE" ]]; then
  lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)
  if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
    rm -f "$LOCK_FILE"
    log "Lock órfão removido (PID $lock_pid não existe mais)"
  fi
fi

exec 9>"$LOCK_FILE"
flock -n 9 || { echo "[boot.sh] Já está em execução. Abortando." >> "$BOOT_LOG"; exit 1; }
echo "$$" > "$LOCK_FILE"

mkdir -p "$LOG_DIR" "$DATA_DIR"

log "=== INÍCIO DO BOOT ==="

if [[ ! -f "$ENV_FILE" ]]; then
  log "ERRO: .env não encontrado em $ENV_FILE"
  exit 1
fi

source "$ENV_FILE"

if [[ "${DISCORD_WEBHOOK_URL:-}" == "SUA_URL_AQUI" ]] || [[ -z "${DISCORD_WEBHOOK_URL:-}" ]]; then
  log "AVISO: DISCORD_WEBHOOK_URL não configurada. Notificações desativadas."
  DISCORD_WEBHOOK_URL=""
fi

if ! pgrep -x crond >/dev/null; then
  crond
  log "crond iniciado"
fi

termux-wake-lock
log "wake-lock adquirido"

sshd
log "sshd iniciado"

cleanup

if [[ -z "$(command -v filebrowser)" ]]; then
  log "ERRO: filebrowser não encontrado no PATH"
  log "Instale com: curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash"
  exit 1
fi

if [[ ! -f "$FB_DB" ]] || [[ ! -s "$FB_DB" ]]; then
  filebrowser -d "$FB_DB" config init 2>/dev/null
  filebrowser -d "$FB_DB" users add admin diy-mobile-2026\! --perm.admin 2>/dev/null
  USER_CREATED=true
  log "Usuário admin / diy-mobile-2026! criado no File Browser"
fi

filebrowser -a 0.0.0.0 -p 8080 -r ~/storage/shared -d "$FB_DB" > "$FB_LOG" 2>&1 &
log "filebrowser iniciado (porta 8080)"

sleep 3

if [[ -z "$(command -v cloudflared)" ]]; then
  log "ERRO: cloudflared não encontrado no PATH"
  exit 1
fi

cloudflared tunnel --url http://localhost:8080 --protocol http2 > "$CF_LOG" 2>&1 &
log "cloudflared tunnel iniciado"

URL=""
count=0
while [[ $count -lt $MAX_RETRIES ]]; do
  URL=$(grep -m 1 -Eo 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "$CF_LOG")
  if [[ -n "$URL" ]]; then
    break
  fi
  sleep "$RETRY_DELAY"
  count=$((count + 1))
done

if [[ -n "$URL" ]]; then
  echo "$URL" > "$URL_FILE"
  log "URL capturada: $URL"

  if [[ -n "$DISCORD_WEBHOOK_URL" ]]; then
    patch_or_post_embed
  fi
else
  log "ERRO: timeout ao capturar URL do Cloudflare"
fi

LOCAL_IP=$(get_local_ip)

echo ""
echo "═══════════════════════════════════════════"
echo "  ✅ Servidor pronto!"
echo ""

if [[ -n "$URL" ]]; then
  echo "  🌐 Público:  $URL"
fi
if [[ -n "$LOCAL_IP" ]]; then
  echo "  🏠 Local:    http://${LOCAL_IP}:8080"
  echo "  💻 SSH:      ssh $(whoami 2>/dev/null || echo "termux")@${LOCAL_IP} -p 8022"
fi
if [[ "$USER_CREATED" == "true" ]]; then
  echo ""
  echo "  👤 Usuário:  admin"
  echo "  🔑 Senha:    diy-mobile-2026!"
  echo "  ⚠️  Troque a senha no primeiro acesso!"
fi
echo ""
echo "  📋 Comandos:"
echo "     status      → status dos serviços"
echo "     cf          → mostra URL atual"
echo "     derrubatudo → desliga todos os serviços"
echo "═══════════════════════════════════════════"
echo ""

log "=== BOOT CONCLUÍDO ==="
