# Guia de uso

Como instalar, ligar, testar e operar o APT Monitor Plus no dia a dia.

## Índice

- [Primeiro uso, passo a passo](#primeiro-uso-passo-a-passo)
- [Comandos](#comandos)
- [Operação do dia a dia](#operação-do-dia-a-dia)
- [Um dia típico](#um-dia-típico)
- [Catálogo de mensagens](#catálogo-de-mensagens)
- [Logs](#logs)
- [Arquivos e backup](#arquivos-e-backup)
- [Atualizar, reinstalar e desinstalar](#atualizar-reinstalar-e-desinstalar)

---

## Primeiro uso, passo a passo

### 1. Instale

```bash
wget https://github.com/AprendendoLinux/apt-monitor-daemon/releases/download/plus-v1.0.0/apt-monitor-plus_1.0-1_all.deb
sudo apt install ./apt-monitor-plus_1.0-1_all.deb
```

O pacote cria `/var/lib/apt-monitor-plus`, protege o `.conf` (modo `0600`), configura o logrotate e **habilita** o
serviço. Ele só **inicia** quando a configuração é válida; no começo ela ainda é o modelo de exemplo, então o
serviço fica parado e o instalador mostra o que falta. Se você vem do APT Monitor clássico, a configuração é migrada
sozinha: veja [Migração](migracao.md).

### 2. Configure os administradores

```bash
sudo nano /etc/apt-monitor-plus/apt-monitor.conf
```

Preencha `[Telegram]` e/ou `[Email]`. É o mínimo para funcionar:

```ini
[Telegram]
BOT_TOKEN=123456789:AAE-abc...
CHAT_IDS=12345678
```

(Como obter token e `chat_id`: [guia do Telegram](../../docs/telegram.md). Todas as opções:
[Referência de configuração](configuracao.md).)

### 3. Valide

```bash
sudo apt-monitor-plus --check-config
```

```text
[INFO] Configuração OK. Canais ativos: telegram
[INFO] Relatório ao cliente: desativado
```

Isso **não envia nada**. Se houver erro, o comando diz o que é e sai com código `78`
(tabela em [Validação e mensagens de erro](configuracao.md#validação-e-mensagens-de-erro)).

### 4. Teste o envio de verdade

```bash
sudo apt-monitor-plus --test-notify
```

Cada canal configurado recebe uma mensagem de teste. Se o cliente estiver configurado, ele recebe um **relatório de
exemplo** marcado como teste. A saída termina com `Teste <canal>: OK` ou `FALHOU` para cada um.

### 5. Ligue o serviço

```bash
sudo systemctl restart apt-monitor-plus
systemctl status apt-monitor-plus
```

Pronto: ao subir, o Plus faz uma checagem imediata e, se houver atualização pendente, **o alerta chega na hora**.

### 6. (Opcional) Configure o cliente

Siga o [guia de configuração do cliente](cliente.md).

---

## Comandos

Todos funcionam como `apt-monitor-plus` ou `apt-monitor` (atalho). Use `sudo`: o programa lê logs e o `.conf`, que
são do root.

| Comando | O que faz |
|---|---|
| `apt-monitor-plus --check-config` | Valida a configuração e mostra os canais ativos de administrador e de cliente. Não envia nada. Código `78` se inválida. |
| `apt-monitor-plus --test-notify` | Envia uma mensagem de teste a **cada** canal (alerta aos administradores, relatório de exemplo ao cliente). Código `1` se algum falhar. |
| `apt-monitor-plus --once` | Faz **uma** checagem de pendências e sai. Envia o alerta se houver novidade. Serve para cron ou diagnóstico. |
| `apt-monitor-plus --dry-run` | Mostra os alertas **sem enviar e sem gravar estado**. Veja o que seria mandado agora. |
| `apt-monitor-plus --report` | Gera e **envia agora** o relatório diário ao cliente. |
| `apt-monitor-plus --report --dry-run` | **Pré-visualiza** o relatório, com o que já consta no histórico do apt desta máquina, sem enviar. |
| `apt-monitor-plus -c ARQUIVO …` | Usa outro arquivo de configuração. |
| `apt-monitor-plus -v …` | Log detalhado. |
| `apt-monitor-plus --version` | Mostra a versão. |
| `man apt-monitor-plus` | Manual. |

### Códigos de saída

| Código | Significado |
|---|---|
| `0` | Tudo certo |
| `1` | Nenhum canal conseguiu entregar (`--once`, `--test-notify`, `--report`) |
| `78` | Configuração inválida (o systemd não reinicia o serviço) |

### Sobre o `--report`

- Envia agora o relatório do que **ainda não foi reportado**. Depois disso, o relatório programado **do mesmo dia não
  é enviado de novo**.
- Sem nada novo a reportar (e sem pendência antiga), o comando diz "Não há atualizações novas para reportar" e não
  envia (a menos que `SEND_EMPTY=true`).
- Sem canal de cliente configurado ele recusa (código `78`), exceto com `--dry-run`, que serve para pré-visualizar.

---

## Operação do dia a dia

```bash
systemctl status apt-monitor-plus             # estado do serviço
sudo journalctl -u apt-monitor-plus -f        # log pelo systemd (acompanhar)
sudo tail -f /var/log/apt-monitor-plus.log    # log próprio (rotação semanal)
sudo systemctl reload apt-monitor-plus        # recarrega o .conf e checa na hora
sudo systemctl restart apt-monitor-plus       # reinicia
sudo systemctl stop apt-monitor-plus          # para
sudo systemctl disable apt-monitor-plus       # não inicia no boot
sudo apt-mark hold <pacote>                   # esse pacote é ignorado pelo monitor
```

**Não é preciso fazer nada** quando você atualiza o servidor: o Plus percebe sozinho, registra o que foi atualizado
e leva isso ao relatório do cliente.

---

## Um dia típico

| Hora | O que acontece |
|---|---|
| 06:00 | O `apt-daily.timer` baixa listas novas e há 5 atualizações. |
| 06:01 | **O Plus percebe a mudança e alerta os administradores** (Telegram e e-mail): "5 pacotes prontos para atualizar (2 de segurança)". |
| 14:10 | O administrador roda `apt update && apt upgrade`; 4 pacotes dão certo e 1 falha. |
| 14:11 | O Plus lê o `history.log`, confere cada pacote no `dpkg.log` e registra: 1 atualização, 4 com sucesso, 1 com falha. O administrador **não recebe relatório**. |
| 17:30 | Uma segunda atualização do mesmo dia: mais 2 pacotes, ambos com sucesso. |
| 22:30 | **O cliente recebe um relatório:** "O administrador Fulano atualizou o servidor 2 vezes… 7 pacotes, 6 com sucesso, 1 com falha". |
| (dias depois) | Se um pacote seguir pendente por **mais de 3 dias**, o relatório das 22:30 passa a listar **todos** os pendentes e a sugerir contato com o administrador. |

---

## Catálogo de mensagens

### Para os administradores (na hora)

| Mensagem | Quando |
|---|---|
| 🚨 **CRÍTICO: ATUALIZAÇÃO DE KERNEL** | Há imagem de kernel (ou metapacote) pendente. `linux-headers` e `linux-firmware` **não** disparam. |
| 🔐 **Atualizações de segurança disponíveis** | Há pacote vindo de repositório `*-security`. |
| ⚠️ **Alerta de Atualização** | Demais atualizações. |
| 🔔 **Lembrete: …** | `REMINDER_DAYS` venceu e nada mudou. |
| ✅ **Servidor em dia** | Tudo foi atualizado (`NOTIFY_ON_CLEAR=true`). |
| 🔁 **Reinicialização necessária** | Apareceu `/var/run/reboot-required`. |
| 🧪 **Teste do APT Monitor** | `--test-notify`. |

Exemplo de Telegram:

```text
🚨 CRÍTICO: ATUALIZAÇÃO DE KERNEL
🖥️ Servidor: srv-prod
🌐 IPs: 192.168.1.50

Temos 3 pacotes prontos para atualizar (2 de segurança).
📦 Alguns deles: linux-image-amd64, openssl, curl
🔁 Reinicialização pendente (linux-image-6.1.76)
```

O e-mail traz o mesmo alerta em HTML, com cartões de totais, selos de **Kernel** e **Segurança**, o comando sugerido
(`sudo apt update && sudo apt upgrade`), o horário da detecção e a tabela de pacotes. Veja a
[galeria](emails.md).

### Para o cliente (1 vez por dia)

| Mensagem | Quando |
|---|---|
| 📋 **Relatório diário de atualizações** | Houve atualização no período. |
| ⏳ **Atenção: atualizações pendentes** | Não houve atualização, mas há pacote pendente há mais de `PENDING_ALERT_DAYS` dias. |
| 📋 **Relatório diário … (há pendências)** | Houve atualização **e** há pendência antiga: tudo num relatório só. |

Detalhes e exemplos em [Relatório diário](relatorio.md).

---

## Logs

O log fica em `/var/log/apt-monitor-plus.log` (e no journal do systemd). Linhas que você vai ver:

| Linha | Significado |
|---|---|
| `=== Iniciando APT Monitor Plus 1.0.0 em srv ===` | O serviço subiu. |
| `Canais: telegram, email \| intervalo: 4.0 hora(s)` | Canais de administrador ativos. |
| `Relatório diário ao cliente (telegram, email) às 22:30 (America/Sao_Paulo).` | Cliente configurado. |
| `Encontrados 5 pacotes pendentes. Crítico (Kernel): True` | Um alerta vai sair. |
| `O apt mudou as listas/pacotes; checando atualizações agora.` | Detecção imediata em ação. |
| `Atualização registrada: 5 pacote(s), 1 com falha.` | O histórico anotou uma atualização do administrador. |
| `Telegram enviado com sucesso para Chat ID: …` / `E-mail enviado com sucesso para: …` | Entregue. |
| `Relatório diário de 2026-11-24 enviado ao cliente (2 atualização(ões)).` | Relatório enviado. |
| `Nenhum canal conseguiu enviar o alerta; nova tentativa em breve.` | Falha de entrega; tenta de novo em até 15 min. |

Token e senha são **removidos de qualquer log**, inclusive de mensagens de erro de rede. O log gira
semanalmente (logrotate), sem reiniciar o serviço.

---

## Arquivos e backup

| Caminho | O que é | Backup? |
|---|---|---|
| `/etc/apt-monitor-plus/apt-monitor.conf` | Configuração (tem credenciais, modo `0600`) | **Sim** |
| `/var/lib/apt-monitor-plus/history.db` | Histórico: atualizações feitas, pendências, relatórios enviados | Recomendado |
| `/var/lib/apt-monitor-plus/state.json` | "O que já foi avisado" aos administradores | Opcional |
| `/var/log/apt-monitor-plus.log` | Log | Não |
| `/var/log/apt/history.log`, `/var/log/dpkg.log` | **Lidos** pelo Plus (são do apt/dpkg) | — |

**Recomeçar do zero** (com o serviço parado):

```bash
sudo systemctl stop apt-monitor-plus
sudo rm /var/lib/apt-monitor-plus/state.json      # volta a avisar as pendências atuais
sudo rm /var/lib/apt-monitor-plus/history.db      # esquece o histórico e as datas das pendências
sudo systemctl start apt-monitor-plus
```

> Apagar o `history.db` zera a contagem de "há quantos dias o pacote está pendente". O banco recomeça "a partir de agora"
> e **não** reenvia atualizações antigas.

---

## Atualizar, reinstalar e desinstalar

```bash
# atualizar para uma versão nova do Plus (a configuração é preservada)
sudo apt install ./apt-monitor-plus_<nova-versão>_all.deb

# remover, mantendo a configuração e o histórico
sudo apt remove apt-monitor-plus

# remover tudo (configuração, estado, histórico e log)
sudo apt purge apt-monitor-plus
```

Ao atualizar, se o `dpkg` perguntar sobre o `.conf` modificado, responda **N** (manter o seu); as chaves novas têm
valor padrão. O modelo completo e comentado fica em
`/usr/share/doc/apt-monitor-plus/examples/apt-monitor.conf`.
