#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# CARREGA VARIÁVEIS DE AMBIENTE DO ARQUIVO .ENV
# ==============================================================================
ENV_FILE="$HOME/.env"

if [ -f "$ENV_FILE" ]; then
    # O comando 'source' (ou .) lê o arquivo e importa as variáveis para o script
    source "$ENV_FILE"
else
    echo "[ERRO]: Arquivo .env não encontrado em $ENV_FILE" >> ~/BOOT_OK.txt
fi

# Log de inicialização (usando >> para manter um histórico das inicializações)
echo "BOOT EXECUTOU $(date)" >> ~/BOOT_OK.txt

# Só inicia o crond se ele já não estiver rodando em segundo plano
if ! pkill -0 crond; then
    crond
fi

# Impede que o Termux entre em suspensão (Essencial para o sistema Android)
termux-wake-lock

# Inicia o servidor SSH silenciosamente
sshd

# Encerra instâncias anteriores para evitar conflitos (ex: porta 8080 presa)
pkill -f filebrowser >/dev/null 2>&1 || true
pkill -f cloudflared >/dev/null 2>&1 || true

# Limpa logs antigos
rm -f ~/cloudflared.log ~/filebrowser.log

# Inicia o Filebrowser em segundo plano
filebrowser -a 0.0.0.0 -p 8080 -r ~/storage/shared > ~/filebrowser.log 2>&1 &

# Pequena pausa apenas para o Filebrowser alocar a porta
sleep 3

# Inicia o túnel do Cloudflared
cloudflared tunnel --url http://localhost:8080 --protocol http2 > ~/cloudflared.log 2>&1 &

# Loop de verificação de URL COM TIMEOUT
MAX_RETRIES=20
count=0
URL=""

while [ $count -lt $MAX_RETRIES ]; do
  URL=$(grep -m 1 -Eo "https://[a-zA-Z0-9.-]*.trycloudflare.com" ~/cloudflared.log)
  if [ -n "$URL" ]; then
    break
  fi
  sleep 2
  count=$((count + 1))
done

# Tratamento do resultado e envio/edição do Webhook
if [ -n "$URL" ]; then
  echo "[Link Publico]: $URL"
  echo "$URL" > ~/URL_ATUAL.txt

  if [ "$DISCORD_WEBHOOK_URL" != "SUA_URL_DO_WEBHOOK_AQUI" ]; then
    # Monta o JSON do Embed
    PAYLOAD=$(cat <<EOF
{
  "embeds": [
    {
      "title": "🚀 Servidor NAS Online!",
      "description": "O túnel do Cloudflare foi atualizado com sucesso no seu Galaxy A14.",
      "color": 3066993,
      "fields": [
        {
          "name": "🔗 Link de Acesso",
          "value": "[Clique aqui para acessar]($URL)"
        },
        {
          "name": "📅 Última Atualização",
          "value": "$(date '+%d/%m/%Y %H:%M:%S')"
        }
      ],
      "footer": {
        "text": "Termux NAS Monitor"
      }
    }
  ]
}
EOF
)

    # Verifica se já temos o ID de uma mensagem anterior guardado
    MSG_ID=""
    if [ -f ~/MSG_ID.txt ]; then
      MSG_ID=$(cat ~/MSG_ID.txt)
    fi

    if [ -n "$MSG_ID" ]; then
      # Tenta EDITAR a mensagem existente (PATCH)
      HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" -X PATCH -d "$PAYLOAD" "${DISCORD_WEBHOOK_URL}/messages/${MSG_ID}")

      # Se o status for 404, significa que a mensagem antiga foi apagada no Discord
      if [ "$HTTP_STATUS" != "200" ]; then
        # Força a criação de uma nova mensagem abaixo
        MSG_ID=""
      fi
    fi

    # Se não existia ID ou a mensagem antiga foi apagada, CRIA uma nova (POST)
    if [ -z "$MSG_ID" ]; then
      # O "?wait=true" no final da URL obriga o Discord a retornar os dados da nova mensagem em formato JSON
      RESPONSE=$(curl -s -H "Content-Type: application/json" -X POST -d "$PAYLOAD" "${DISCORD_WEBHOOK_URL}?wait=true")

      # Extrai o ID da nova mensagem usando grep e sed (evita precisar instalar o jq)
      NEW_ID=$(echo "$RESPONSE" | grep -o '"id": *"[0-9]*"' | head -n 1 | sed 's/[^0-9]//g')

      # Se conseguiu capturar o ID, salva no arquivo
      if [ -n "$NEW_ID" ]; then
        echo "$NEW_ID" > ~/MSG_ID.txt
      fi
    fi
  fi

else
  echo "[Erro]: Timeout ao gerar a URL do Cloudflare. Verifique sua conexão."
  echo "FALHA NO CLOUDFLARE $(date)" >> ~/BOOT_OK.txt
fi