<div align="center">

# 📦 APT Monitor Daemon

**Saiba na hora quando seus servidores Debian/Ubuntu têm atualizações pendentes — sem spam.**

[![CI](https://github.com/AprendendoLinux/apt-monitor-daemon/actions/workflows/ci.yml/badge.svg)](https://github.com/AprendendoLinux/apt-monitor-daemon/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/AprendendoLinux/apt-monitor-daemon?label=vers%C3%A3o)](https://github.com/AprendendoLinux/apt-monitor-daemon/releases/latest)
![Debian](https://img.shields.io/badge/Debian-11%20%7C%2012%20%7C%2013-A81D33?logo=debian&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420?logo=ubuntu&logoColor=white)
![Python](https://img.shields.io/badge/Python-%E2%89%A5%203.6-3776AB?logo=python&logoColor=white)

</div>

Daemon leve em Python, executado pelo `systemd`, que verifica periodicamente as atualizações do APT e avisa por
**Telegram** e/ou **e-mail (HTML)**. Destaca atualizações de **kernel** e de **segurança**, avisa quando é preciso
**reiniciar** e lembra o que já foi notificado — então você recebe **um alerta por novidade**, não um por checagem.

## Índice

- [Por que usar](#-por-que-usar)
- [Início rápido](#-início-rápido)
- [Como são os alertas](#-como-são-os-alertas)
- [Instalação](#-instalação)
- [Configuração](#️-configuração)
- [Linha de comando](#-linha-de-comando)
- [Operação do dia a dia](#-operação-do-dia-a-dia)
- [Segurança](#-segurança)
- [Compatibilidade](#-compatibilidade)
- [Perguntas frequentes](#-perguntas-frequentes)
- [Documentação](#-documentação)
- [Desenvolvimento e contribuição](#-desenvolvimento-e-contribuição)

## 🌟 Por que usar

| | |
|---|---|
| 🔕 **Sem repetição** | O estado fica em disco (`/var/lib/apt-monitor`). Reiniciar o serviço, o servidor ou atualizar o pacote **não** reenvia alertas. Só avisa quando surge pacote/versão novo. |
| 🚨 **Kernel crítico** | Só imagens de kernel e metapacotes disparam o alerta crítico — `linux-headers` e `linux-firmware` não. |
| 🔐 **Segurança** | Atualizações vindas de repositórios `*-security` são destacadas e contadas. |
| 🔁 **Reboot pendente** | Avisa quando existe `/var/run/reboot-required`. |
| 📬 **Vários destinos** | Vários chats do Telegram e vários e-mails; a falha de um não afeta os outros. |
| 🛡️ **Resiliente** | Timeouts, novas tentativas e retentativa do alerta se nada foi entregue. Falha do `apt` **não** vira "tudo em dia". |
| 🔒 **Seguro por padrão** | Credenciais nunca aparecem em logs, `.conf` com `0600`, serviço com hardening do systemd, SMTP sempre sob TLS. |
| 🪶 **Leve** | Uma única dependência: `python3-apt`. Python ≥ 3.6. |

## ⚡ Início rápido

```bash
# 1. instalar (baixe o .deb em Releases)
sudo apt install ./apt-monitor_1.1-1_all.deb

# 2. configurar Telegram e/ou e-mail
sudo nano /etc/apt-monitor/apt-monitor.conf

# 3. validar e testar
sudo apt-monitor --check-config
sudo apt-monitor --test-notify

# 4. iniciar
sudo systemctl restart apt-monitor
```

## 🚀 Como são os alertas

### Telegram

> 🚨 **CRÍTICO: ATUALIZAÇÃO DE KERNEL**
> 🖥️ **Servidor:** saopaulo
> 🌐 **IPs:** 192.168.1.50, 2001:db8::50
>
> Temos 8 pacotes prontos para atualizar (2 de segurança).
> 📦 Alguns deles: openssl, libssl3, linux-image-amd64, tzdata, ufw...
> 🔁 **Reinicialização pendente**

| Título | Quando |
|---|---|
| 🚨 CRÍTICO: ATUALIZAÇÃO DE KERNEL | há imagem de kernel/metapacote pendente |
| 🔐 Atualizações de segurança disponíveis | há pacote de repositório `-security` |
| ⚠️ Alerta de Atualização | demais atualizações |
| 🔔 Lembrete: … | `REMINDER_DAYS` venceu e nada mudou |
| ✅ Servidor em dia | tudo atualizado (`NOTIFY_ON_CLEAR=true`) |
| 🔁 Reinicialização necessária | `reboot-required` apareceu |

### E-mail

HTML responsivo com tarja colorida pela gravidade (azul, laranja, vermelha), tabela *pacote · versão instalada → nova ·
segurança* e alternativa em texto puro. Cada destinatário recebe a própria mensagem.

## 📥 Instalação

### Pelo `.deb` (recomendado)

Baixe o arquivo mais recente em **[Releases](https://github.com/AprendendoLinux/apt-monitor-daemon/releases/latest)**
(há também o `SHA256SUMS` para conferir a integridade):

```bash
sha256sum -c SHA256SUMS --ignore-missing
sudo apt install ./apt-monitor_1.1-1_all.deb
```

O pacote copia os arquivos, cria `/var/lib/apt-monitor`, protege o `.conf` (`0600`), configura o `logrotate` e
**habilita** o serviço. Ele só **inicia** se a configuração já for válida; caso contrário, mostra o que falta.

### Gerando o pacote você mesmo

```bash
git clone https://github.com/AprendendoLinux/apt-monitor-daemon && cd apt-monitor-daemon
./build.sh                                   # → dist/apt-monitor_<versão>_all.deb (compressão xz)
sudo apt install ./dist/apt-monitor_*_all.deb
```

### Atualizando

```bash
sudo apt install ./apt-monitor_<nova-versão>_all.deb
```

> **Vindo da v1.0?** O `dpkg` perguntará sobre o `.conf` modificado: responda **N** (manter o seu); as chaves novas
> têm valores padrão. O script antigo em `/opt/apt-monitor` é removido sozinho e o serviço é religado.

### Desinstalando

```bash
sudo apt remove apt-monitor    # mantém /etc/apt-monitor
sudo apt purge apt-monitor     # remove também configuração, estado e log
```

## ⚙️ Configuração

Arquivo: `/etc/apt-monitor/apt-monitor.conf`. Depois de editar: `sudo systemctl reload apt-monitor`.

```ini
[Telegram]
BOT_TOKEN=123456789:AAE...               # com ou sem o prefixo "bot"; vazio = desativa o Telegram
CHAT_IDS=12345678, -1001234567890        # vários, separados por vírgula
#API_BASE=https://api.telegram.org

[Monitor]
CHECK_INTERVAL_HOURS=4                   # aceita decimais (0.5 = 30 min); mínimo efetivo: 1 min
REMINDER_DAYS=0                          # repete o alerta a cada N dias enquanto houver pendência (0 = nunca)
NOTIFY_ON_CLEAR=false                    # avisa quando tudo for atualizado
UPDATE_CACHE=true                        # executa o equivalente a "apt update" a cada ciclo
IGNORE_INTERFACES=lo,docker*,br-*,veth*,virbr*,cni*,flannel*,cali*,tun*,tap*

[Email]
SMTP_SERVER=smtp.exemplo.com             # vazio = desativa o e-mail
SMTP_PORT=587
SMTP_SECURITY=auto                       # auto | ssl | starttls | none
SMTP_USER=alerta@exemplo.com             # vazio = sem autenticação (relay local)
SMTP_PASS=sua_senha_segura
SENDER_NAME=APT Monitor
SENDER_EMAIL=alerta@exemplo.com
RECIPIENT_EMAILS=admin@exemplo.com, suporte@exemplo.com
```

| Chave | Padrão | Descrição |
|---|---|---|
| `CHECK_INTERVAL_HOURS` | `4` | Intervalo entre checagens. |
| `REMINDER_DAYS` | `0` | Lembrete periódico enquanto houver pendências. |
| `NOTIFY_ON_CLEAR` | `false` | Envia "Servidor em dia" quando a fila zera. |
| `UPDATE_CACHE` | `true` | Atualiza as listas do APT a cada ciclo (precisa de root). Use `false` se outro mecanismo já faz isso. |
| `IGNORE_INTERFACES` | `lo,docker*,…` | Interfaces fora da lista de IPs (curingas). |
| `LOG_FILE` / `STATE_FILE` | `/var/log/apt-monitor.log` / `/var/lib/apt-monitor/state.json` | Caminhos; `LOG_FILE=` vazio = só stdout/journal. |
| `SMTP_SECURITY` | `auto` | `auto`: 465 → SSL, demais → STARTTLS quando oferecido (recusa enviar senha sem TLS). |

Valores de exemplo (`seu_bot_token_aqui`, `smtp.seuservidor.com`…) contam como "não configurado". Se nenhum canal
for válido, o serviço sai com código 78 e o systemd **não** entra em loop de reinício.

Guias passo a passo: **[Telegram](docs/telegram.md)** · **[E-mail/SMTP](docs/email.md)** (Gmail, Microsoft 365, SSL, relay local).

## 🧰 Linha de comando

| Comando | Função |
|---|---|
| `apt-monitor --check-config` | Valida a configuração (código 78 se inválida). |
| `apt-monitor --test-notify` | Envia uma mensagem de teste a cada canal. |
| `apt-monitor --once` | Faz uma checagem e sai (cron/timer). |
| `apt-monitor --dry-run` | Mostra os alertas sem enviar nem gravar estado. |
| `apt-monitor -c ARQUIVO` | Usa outro arquivo de configuração. |
| `apt-monitor --version` | Mostra a versão. |

Manual: `man apt-monitor`.

## 🔧 Operação do dia a dia

```bash
systemctl status apt-monitor                 # estado do serviço
sudo journalctl -u apt-monitor -f            # logs pelo systemd
sudo tail -f /var/log/apt-monitor.log        # log próprio (rotação semanal, sem reiniciar o serviço)
sudo systemctl reload apt-monitor            # recarrega o .conf e faz uma checagem imediata
sudo systemctl restart apt-monitor           # reinicia
sudo apt-mark hold <pacote>                  # pacotes em hold são ignorados
sudo rm /var/lib/apt-monitor/state.json      # (com o serviço parado) esquece o que já foi notificado
```

## 🔒 Segurança

- Token do Telegram e senha SMTP são **removidos de qualquer log**, inclusive de mensagens de erro de rede.
- `/etc/apt-monitor/apt-monitor.conf` é instalado com modo **0600**.
- Credenciais SMTP só trafegam **sob TLS** (a menos que você force `SMTP_SECURITY=none`).
- Unit do systemd com `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`, `PrivateDevices`,
  `RestrictAddressFamilies`, entre outros — verifique com `systemd-analyze security apt-monitor`.
- Todo texto dinâmico é escapado (HTML), evitando injeção por nomes de pacote ou hostname.

Encontrou uma vulnerabilidade? Veja a [política de segurança](SECURITY.md).

## ✅ Compatibilidade

Testado automaticamente (instalação do `.deb`, upgrade da v1.0, alertas, restart, purge) em containers, e com
**systemd real** em Debian 12 e Ubuntu 24.04:

| Distribuição | Python | Status |
|---|---|---|
| Debian 11 (bullseye) | 3.9 | ✅ |
| Debian 12 (bookworm) | 3.11 | ✅ (também com systemd) |
| Debian 13 (trixie) | 3.13 | ✅ |
| Ubuntu 20.04 | 3.8 | ✅ |
| Ubuntu 22.04 | 3.10 | ✅ |
| Ubuntu 24.04 | 3.12 | ✅ (também com systemd) |

Os testes unitários rodam também em Python 3.6. Derivados (Linux Mint, Raspberry Pi OS, Pop!_OS…) funcionam desde
que tenham `apt`, `python3-apt` e `systemd`.

## ❓ Perguntas frequentes

**Vai atualizar meus pacotes sozinho?** Não. Ele só **avisa**. (O máximo que faz no sistema é o equivalente a
`apt update`, e dá para desligar com `UPDATE_CACHE=false`.)

**Posso usar só Telegram ou só e-mail?** Sim: deixe o outro canal vazio.

**Preciso de internet no servidor?** Para o `apt update` e para enviar os alertas, sim.

**Recebi o mesmo aviso duas vezes.** Só deve ocorrer se você apagou o `state.json` ou se há versões novas dos pacotes.
Veja [Solução de problemas](docs/solucao-de-problemas.md).

**Funciona com `unattended-upgrades`?** Sim. Se um upgrade automático estiver segurando o lock do apt, o daemon usa a
lista local naquele ciclo e tenta de novo no próximo.

**Posso adicionar Discord/Slack/ntfy?** Sim — crie uma classe com `name` e `send(alert)`; veja
[a arquitetura](docs/arquitetura.md#estrutura-do-código).

## 📚 Documentação

- [Configurando o Telegram](docs/telegram.md)
- [Configurando o e-mail (SMTP)](docs/email.md)
- [Como funciona (fluxo, estado, segurança)](docs/arquitetura.md)
- [Solução de problemas](docs/solucao-de-problemas.md)
- [Changelog](CHANGELOG.md) · [Contribuindo](CONTRIBUTING.md) · [Segurança](SECURITY.md)

## 🛠️ Desenvolvimento e contribuição

```bash
python3 -m unittest discover -s tests -v   # testes unitários
./build.sh                                  # gera o .deb em dist/
tests/docker/run-matrix.sh                  # instala o .deb em containers Debian/Ubuntu
tests/docker/systemd-test.sh                # idem, com systemd real
```

Veja [CONTRIBUTING.md](CONTRIBUTING.md). Releases são geradas automaticamente ao criar uma tag `vX.Y.Z`.

---

<div align="center">Feito por <a href="https://github.com/AprendendoLinux">AprendendoLinux</a> · Mantido por Luiz Marques</div>
