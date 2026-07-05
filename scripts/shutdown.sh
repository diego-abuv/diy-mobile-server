#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# DIY MOBILE SERVER — SHUTDOWN (DESLIGA TODOS OS SERVIÇOS)
# ==============================================================================

PROJECT_DIR="${HOME}/diy-mobile-server"
LOG_DIR="${PROJECT_DIR}/logs"
SHUT_LOG="${LOG_DIR}/shutdown.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$SHUT_LOG"
}

echo "═══════════════════════════════════════════"
echo "         🛑 Desligando servidor..."
echo "═══════════════════════════════════════════"

pkill -f cloudflared 2>/dev/null && echo "  ✅ cloudflared parado"   || echo "  ℹ️  cloudflared não estava rodando"
pkill -f filebrowser 2>/dev/null && echo "  ✅ filebrowser parado"   || echo "  ℹ️  filebrowser não estava rodando"

if pgrep -x crond >/dev/null; then
  pkill -x crond 2>/dev/null && echo "  ✅ crond parado"
fi

termux-wake-unlock 2>/dev/null && echo "  ✅ wake-lock liberado"

rm -f "${TMPDIR:-/data/data/com.termux/files/usr/tmp}"/diy-*.lock 2>/dev/null
echo "  ✅ locks removidos"

log "Servidor desligado"

echo ""
echo "═══════════════════════════════════════════"
echo "  🛑 Servidor desligado em $(date '+%d/%m/%Y %H:%M:%S')"
echo ""
echo "  ▶️  Para reiniciar: startenv"
echo "  ℹ️  SSH permanece ativo (porta 8022)"
echo "═══════════════════════════════════════════"
echo ""
