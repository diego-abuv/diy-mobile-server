# 📱 DIY Mobile Server

Este projeto transforma um dispositivo Android antigo em um servidor funcional com acesso remoto (SSH), gerenciador de arquivos (File Browser) e túnel de acesso externo (Cloudflare), tudo automatizado via Termux.

## 🚀 Funcionalidades

- **Acesso Remoto**: SSH configurado para gestão via terminal.
- **Interface Web**: File Browser para gerenciar arquivos do celular pelo navegador.
- **Acesso Externo**: Túnel Cloudflare para acessar o servidor de qualquer lugar do mundo sem abrir portas no roteador.
- **Auto-start**: Inicialização automática ao ligar o celular.

## 📦 1. Pré-requisitos

Instale os seguintes aplicativos no seu Android (preferencialmente via F-Droid para versões mais atualizadas):

1.  **Termux**: O terminal principal.
2.  **Termux:Boot**: Necessário para iniciar o script automaticamente no boot do sistema.
3.  **Termux:API** (Opcional): Para futuras integrações com hardware do celular (bateria, sensores, etc).

> **Importante**: Desative a "Otimização de Bateria" para o Termux nas configurações do Android para evitar que o sistema encerre o servidor em segundo plano.

## ⚙️ 2. Preparação Inicial

Abra o Termux e execute os comandos abaixo para atualizar o sistema e instalar as dependências básicas:

```bash
pkg update && pkg upgrade -y
pkg install git curl nano openssh netcat-openbsd cloudflared -y
```

### Habilitar Armazenamento
Para que o servidor consiga acessar seus arquivos internos:
```bash
termux-setup-storage
```
*Aceite a permissão de arquivos que aparecerá no Android.*

## 🔐 3. Configuração do SSH

1. Defina uma senha para o seu usuário:
   ```bash
   passwd
   ```
2. Descubra seu nome de usuário:
   ```bash
   whoami
   ```
3. O servidor SSH inicia na porta `8022`. Para conectar do PC:
   ```bash
   ssh [seu_usuario]@[IP_DO_CELULAR] -p 8022
   ```

## 📁 4. Instalação do File Browser

Instale o binário do File Browser:
```bash
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
```

## 🚀 5. Automação e Script Principal

O script `script.sh` orquestra todos os serviços. Para configurá-lo como script de inicialização:

1. Crie a pasta de boot:
   ```bash
   mkdir -p ~/.termux/boot
   ```
2. O script deve ser colocado em `~/.termux/boot/start-services.sh` (ou linkado para lá).
3. Garanta que ele tenha permissão de execução:
   ```bash
   chmod +x script.sh
   ```

### Atalhos (Aliases)
Adicione estas linhas ao seu `~/.bashrc` para facilitar o uso diário:

```bash
# Iniciar o ambiente manualmente
alias startenv='echo "[INFO] Iniciando ambiente..."; bash ~/script.sh'

# Ver o link atual do Cloudflare
alias cf='cat ~/URL_ATUAL.txt'
```
Após editar, execute `source ~/.bashrc`.

## 🛠 6. Estrutura do Sistema

| Serviço | Porta | Função |
| :--- | :--- | :--- |
| **SSHD** | 8022 | Acesso via terminal remoto |
| **File Browser** | 8080 | Interface web para arquivos |
| **Cloudflared** | - | Túnel para acesso externo HTTPS |
| **script.sh** | - | Orquestrador de serviços e logs |

## 🔍 7. Como Usar

### Acesso Local
Se você estiver na mesma rede Wi-Fi:
- **File Browser**: `http://[IP_DO_CELULAR]:8080`
- **SSH**: `ssh [user]@[IP] -p 8022`

### Acesso Externo
O script salva automaticamente a URL temporária do Cloudflare no arquivo `~/URL_ATUAL.txt`. 
Use o comando `cf` para ver o link e acessar de qualquer lugar.

## ⚠️ Regras e Avisos

1.  **Conflitos**: O script encerra instâncias anteriores do `cloudflared` e `filebrowser` antes de iniciar novas para evitar erros de porta ocupada.
2.  **Logs**: Verifique `~/cloudflared.log` ou `~/filebrowser.log` caso algo não funcione.
3.  **Boot**: O Termux:Boot precisa ser aberto manualmente uma vez após a instalação para que o Android permita que ele inicie no boot.
4.  **Cloudflare**: A URL gerada no modo "Quick Tunnel" muda toda vez que o serviço é reiniciado. Caso precise de uma URL fixa é necessária outra abordagem para definir uma URL fixa apontando para o ip utilizando domínio pago.

---
**Arquitetura Final:**
```text
Android Device
 ├── SSH (Porta 8022)
 ├── File Browser (Porta 8080)
 ├── Cloudflare Tunnel (HTTPS Externo)
 └── Termux Boot (Auto-inicialização)
```