#!/data/data/com.termux/files/usr/bin/bash
set -o nounset
set -o pipefail

# ==============================================================================
# DIY MOBILE SERVER — INSTALADOR AUTOMÁTICO
# ==============================================================================

REPO_DIR="${HOME}/diy-mobile-server"

echo "=== DIY Mobile Server — Instalação ==="

echo ""
echo "[1/6] Atualizando pacotes..."
pkg update -y && pkg upgrade -y

echo ""
echo "[2/6] Instalando dependências..."
pkg install -y git curl openssh cloudflared cronie termux-api

echo ""
echo "[3/6] Criando estrutura de diretórios..."
mkdir -p "${REPO_DIR}/scripts" "${REPO_DIR}/data" "${REPO_DIR}/logs"

echo ""
echo "[4/6] Configurando scripts..."
if [[ -f "scripts/boot.sh" ]]; then
  cp scripts/boot.sh "${REPO_DIR}/scripts/"
  cp scripts/watchdog.sh "${REPO_DIR}/scripts/"
  cp scripts/status.sh "${REPO_DIR}/scripts/"
  chmod +x "${REPO_DIR}/scripts/"*.sh
fi

echo ""
echo "[5/6] Configurando Termux:Boot..."
mkdir -p "${HOME}/.termux/boot"
cat > "${HOME}/.termux/boot/boot.sh" <<'BOOTEOF'
#!/data/data/com.termux/files/usr/bin/bash
exec bash "${HOME}/diy-mobile-server/scripts/boot.sh"
BOOTEOF
chmod +x "${HOME}/.termux/boot/boot.sh"

echo ""
echo "[6/6] Configurando aliases e watchdog..."

# Aliases no bashrc
ALIAS_BLOCK="
# DIY Mobile Server
alias cf='cat ${REPO_DIR}/data/current_url.txt'
alias derrubacf='pkill -f cloudflared >/dev/null 2>&1 || true && echo \"[OK] Túnel derrubado!\"'
alias startenv='echo \"[INFO] Iniciando ambiente...\"; bash ${REPO_DIR}/scripts/boot.sh'
alias status='bash ${REPO_DIR}/scripts/status.sh'
alias pingarcf='bash ${REPO_DIR}/scripts/watchdog.sh && echo \"[OK] Watchdog executado\"'
"
if ! grep -q "DIY Mobile Server" "${HOME}/.bashrc" 2>/dev/null; then
  echo "$ALIAS_BLOCK" >> "${HOME}/.bashrc"
  echo "  Aliases adicionados ao ~/.bashrc"
else
  echo "  Aliases já existem no ~/.bashrc — pulando"
fi

# Watchdog no crontab
(crontab -l 2>/dev/null | grep -v "watchdog.sh"; echo "*/5 * * * * bash ${REPO_DIR}/scripts/watchdog.sh") | crontab -
echo "  Watchdog configurado no crontab (a cada 5 min)"

echo ""
echo "=== Instalação concluída! ==="
echo ""
echo "Próximos passos:"
echo "  1. Crie o arquivo ~/.env com:"
echo "     nano ~/.env"
echo "     Conteúdo: DISCORD_WEBHOOK_URL=\"https://discord.com/api/webhooks/SEU_WEBHOOK\""
echo ""
echo "  2. Execute (se ainda não fez):"
echo "     termux-setup-storage"
echo "     passwd"
echo ""
echo "  3. Reinicie o celular ou execute manualmente:"
echo "     bash ${REPO_DIR}/scripts/boot.sh"
echo ""
