#!/data/data/com.termux/files/usr/bin/bash
set -o nounset
set -o pipefail

# ==============================================================================
# DIY MOBILE SERVER — WATCHDOG (MONITOR ANTI-QUEDA)
# ==============================================================================

PROJECT_DIR="${HOME}/diy-mobile-server"
LOG_DIR="${PROJECT_DIR}/logs"
BOOT_SCRIPT="${PROJECT_DIR}/scripts/boot.sh"
WD_LOG="${LOG_DIR}/watchdog.log"
LOCK_FILE="/tmp/diy-watchdog.lock"

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$WD_LOG"; }

cf_alive=false
fb_alive=false
ssh_alive=false

pkill -0 -f cloudflared 2>/dev/null && cf_alive=true
curl -s -o /dev/null --max-time 5 http://localhost:8080 2>/dev/null && fb_alive=true
pgrep -x sshd >/dev/null 2>&1 && ssh_alive=true

if $cf_alive && $fb_alive && $ssh_alive; then
  exit 0
fi

$cf_alive || log "SERVIÇO FORA: cloudflared"
$fb_alive || log "SERVIÇO FORA: filebrowser (porta 8080)"
$ssh_alive || log "SERVIÇO FORA: sshd (porta 8022)"

log "Reiniciando serviços via boot.sh..."
bash "$BOOT_SCRIPT"
log "Watchdog: execução concluída"
