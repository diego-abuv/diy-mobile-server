#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# DIY MOBILE SERVER — STATUS DASHBOARD
# ==============================================================================

PROJECT_DIR="${HOME}/diy-mobile-server"
LOG_DIR="${PROJECT_DIR}/logs"
DATA_DIR="${PROJECT_DIR}/data"

BOOT_LOG="${LOG_DIR}/boot.log"
WD_LOG="${LOG_DIR}/watchdog.log"
URL_FILE="${DATA_DIR}/current_url.txt"
MSG_ID_FILE="${DATA_DIR}/msg_id.txt"

mkdir -p "$LOG_DIR" "$DATA_DIR" 2>/dev/null

decode_snowflake() {
  local id=$1
  local ts_ms=$(( (id >> 22) + 1420070400000 ))
  date -d "@$((ts_ms / 1000))" '+%d/%m/%Y %H:%M:%S' 2>/dev/null || echo "n/a"
}

echo "═══════════════════════════════════════════"
echo "         📡 NAS SERVER STATUS"
echo "═══════════════════════════════════════════"

# ─── SAÚDE GERAL ───
echo ""
ERRORS=0
for svc in sshd filebrowser cloudflared crond; do
  if ! pgrep -x "$svc" >/dev/null 2>&1; then
    ERRORS=$((ERRORS + 1))
  fi
done

if [ "$ERRORS" -eq 0 ]; then
  echo "  ✅ SISTEMA SAUDÁVEL — todos os serviços rodando"
else
  echo "  ⚠️  SISTEMA COM PROBLEMAS — $ERRORS serviço(s) parado(s)"
fi

# ─── SERVIÇOS ───
echo ""
echo "◆ SERVIÇOS"
for svc in sshd filebrowser cloudflared crond; do
  pid=$(pgrep -x "$svc" 2>/dev/null)
  if [ -n "$pid" ]; then
    uptime=$(ps -o etime= -p "$pid" 2>/dev/null | xargs)
    echo "  ✅ $svc  (PID $pid — up $uptime)"
  else
    echo "  ❌ $svc  PARADO"
  fi
done

# ─── RECURSOS ───
echo ""
echo "◆ RECURSOS"
free -h | awk '
/Mem:/ {printf "  RAM:    %s usado / %s total (%s livre)\n", $3, $2, $4}
/Swap:/ {printf "  Swap:   %s usado / %s total\n", $3, $2}'
echo "  CPU:    $(uptime | grep -oP 'load average:.*' | sed 's/load average://')"

# ─── DISCO ───
echo ""
echo "◆ DISCO"
MMC_SIZE=$(cat /sys/block/mmcblk0/size 2>/dev/null)
if [ -n "$MMC_SIZE" ]; then
  TOTAL_GB=$(( MMC_SIZE * 512 / 1000000000 ))
  echo "  eMMC:   ${TOTAL_GB}GB (chip)"
fi
df -h /storage/emulated/0 2>/dev/null | tail -1 | \
  awk '{printf "  Shared:  %s usado / %s total (%s livre) — %s\n", $3, $2, $4, $5}'

# ─── REDE ───
echo ""
echo "◆ REDE"
ip -4 addr show wlan0 2>/dev/null | grep -oP 'inet \K[\d.]+' | \
  xargs -I{} echo "  IP:      {}"
echo "  URL:     $(cat "$URL_FILE" 2>/dev/null || echo 'n/a')"

# ─── DISCORD × BOOT ───
echo ""
echo "◆ SINCRONIA"
LAST_BOOT_RAW=$(grep "BOOT CONCLUÍDO" "$BOOT_LOG" 2>/dev/null | tail -1 | sed 's/\[//;s/\].*//' || echo "")
if [ -n "$LAST_BOOT_RAW" ]; then
  echo "  Último boot:  $LAST_BOOT_RAW"
fi
if [ -f "$MSG_ID_FILE" ] && [ -n "$(cat "$MSG_ID_FILE")" ]; then
  MSG_DATE=$(decode_snowflake "$(cat "$MSG_ID_FILE")")
  echo "  Última notif:  $MSG_DATE (Discord)"
fi

# ─── WATCHDOG ───
echo ""
echo "◆ WATCHDOG"
echo "  Atuações: $(wc -l < "$WD_LOG" 2>/dev/null || echo 0)"

echo ""
echo "═══════════════════════════════════════════"
