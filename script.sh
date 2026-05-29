#!/data/data/com.termux/files/usr/bin/bash

# Log de inicialização (usando >> para manter um histórico das inicializações)
echo "BOOT EXECUTOU $(date)" >> ~/BOOT_OK.txt

# Impede que o Termux entre em suspensão (Essencial para o sistema Android)
termux-wake-lock

# Inicia o servidor SSH silenciosamente
sshd

# Encerra instâncias anteriores para evitar conflitos (ex: porta 8080 presa)
# O "|| true" evita que o script quebre (exit code 1) caso não exista o processo
pkill -f filebrowser >/dev/null 2>&1 || true
pkill -f cloudflared >/dev/null 2>&1 || true

# Limpa logs antigos
rm -f ~/cloudflared.log ~/filebrowser.log

# Inicia o Filebrowser em segundo plano
# Nota: Garanta que rodou 'termux-setup-storage' antes para o diretório shared existir
filebrowser -a 0.0.0.0 -p 8080 -r ~/storage/shared > ~/filebrowser.log 2>&1 &

# Pequena pausa apenas para o Filebrowser alocar a porta
sleep 3

# Inicia o túnel do Cloudflared
cloudflared tunnel --url http://localhost:8080 --protocol http2 > ~/cloudflared.log 2>&1 &

# Loop de verificação de URL COM TIMEOUT (evita loop infinito que trava o celular)
MAX_RETRIES=20
count=0
URL=""

while [ $count -lt $MAX_RETRIES ]; do
  # Pega a primeira ocorrência da URL com -m 1
  URL=$(grep -m 1 -Eo "https://[a-zA-Z0-9.-]*\.trycloudflare\.com" ~/cloudflared.log)

  if [ -n "$URL" ]; then
    break
  fi

  sleep 2
  count=$((count + 1))
done

# Tratamento do resultado
if [ -n "$URL" ]; then
  echo "[Link Publico]: $URL"
  echo "$URL" > ~/URL_ATUAL.txt # Salva a URL num arquivo de fácil acesso
else
  echo "[Erro]: Timeout ao gerar a URL do Cloudflare. Verifique sua conexão."
  echo "FALHA NO CLOUDFLARE $(date)" >> ~/BOOT_OK.txt
fi