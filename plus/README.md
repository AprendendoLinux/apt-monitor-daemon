<div align="center">

# 📦 APT Monitor **Plus**

**Alertas imediatos para os administradores. Prestação de contas diária para o cliente.**

[![CI](https://github.com/AprendendoLinux/apt-monitor-daemon/actions/workflows/ci.yml/badge.svg)](https://github.com/AprendendoLinux/apt-monitor-daemon/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/AprendendoLinux/apt-monitor-daemon?filter=plus-v*&label=Plus)](https://github.com/AprendendoLinux/apt-monitor-daemon/releases?q=plus-v)
![Debian](https://img.shields.io/badge/Debian-11%20%7C%2012%20%7C%2013-A81D33?logo=debian&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420?logo=ubuntu&logoColor=white)
![Python](https://img.shields.io/badge/Python-%E2%89%A5%203.6-3776AB?logo=python&logoColor=white)
[![Licença](https://img.shields.io/github/license/AprendendoLinux/apt-monitor-daemon?label=licen%C3%A7a)](../LICENSE)

</div>

O **APT Monitor Plus** é a edição completa do [APT Monitor](../README.md): um daemon leve para servidores
Debian/Ubuntu que faz **duas coisas** para dois públicos diferentes.

| Para quem | O que recebe | Quando |
|---|---|---|
| 🛠️ **Administradores** | **Alerta de atualização disponível**, por Telegram e/ou e-mail: destaca **kernel** e **segurança** e avisa quando é preciso **reiniciar** | **Na hora** (cerca de 1 minuto depois que o apt detecta) |
| 🧑‍💼 **Cliente** | **Relatório diário** do trabalho feito: quantas vezes o administrador atualizou o servidor e o total de pacotes (**com sucesso** e **com falha**). Se algo fica pendente há mais de 3 dias, avisa e sugere falar com o administrador | **Uma vez por dia**, no horário que você definir |

| 📨 Alerta aos administradores | 📋 Relatório ao cliente |
|---|---|
| ![Alerta](docs/img/email-admin-alerta.png) | ![Relatório](docs/img/email-cliente-relatorio.png) |

## Índice

- [Clássico ou Plus?](#clássico-ou-plus)
- [Recursos](#recursos)
- [Como funciona](#como-funciona)
- [Instalação](#instalação)
- [Início rápido](#início-rápido)
- [Configuração](#configuração)
- [Uso](#uso)
- [O relatório do cliente](#o-relatório-do-cliente)
- [Segurança e privacidade](#segurança-e-privacidade)
- [Compatibilidade](#compatibilidade)
- [Perguntas frequentes](#perguntas-frequentes)
- [Documentação](#documentação)
- [Desenvolvimento](#desenvolvimento)

## Clássico ou Plus?

| | **Clássico** | **Plus** |
|---|---|---|
| Alertas aos administradores (Telegram e e-mail) | ✅ | ✅ |
| Destaque de kernel, segurança e reinício pendente | ✅ | ✅ |
| **Alerta imediato** quando o apt muda (≈ 1 min) | — | ✅ |
| **E-mails novos** (cabeçalho por gravidade, cartões, selos, celular) | — | ✅ |
| **Relatório diário ao cliente** (Telegram e/ou e-mail) | — | ✅ |
| **Aviso de pendência antiga** ao cliente | — | ✅ |
| **Histórico** do que foi atualizado, com sucesso/falha por pacote | — | ✅ (SQLite) |
| Dependências | `python3-apt` | `python3-apt` + `tzdata` |

**Escolha o Plus** se você presta serviço a alguém (cliente, chefia, outra equipe) e quer **mostrar o trabalho feito**
de forma automática, ou se quer os alertas mais rápidos e mais claros. **Fique no clássico** se só precisa do alerta
simples. O Plus **substitui** o clássico: veja a [migração](docs/migracao.md), que preserva a sua configuração.

## Recursos

| | |
|---|---|
| ⚡ **Alerta imediato** | Reage em cerca de 1 minuto quando o apt baixa listas novas ou instala pacotes, sem esperar o intervalo. |
| 🚨 **Kernel crítico** | Só imagens de kernel e metapacotes disparam o crítico; `linux-headers` e `linux-firmware` não. |
| 🔐 **Segurança** | Atualizações de repositórios `*-security` são destacadas e contadas. |
| 🔁 **Reinício pendente** | Avisa quando existe `/var/run/reboot-required`. |
| 📋 **Relatório diário** | Quantas vezes o administrador atualizou e quantos pacotes (sucesso/falha), por Telegram e/ou e-mail. |
| ✅ **Sucesso real, pacote a pacote** | Confere no `dpkg.log` se cada pacote chegou à versão nova. |
| ⏳ **Pendência antiga** | Mais de N dias parado? O cliente recebe a lista completa e a sugestão de falar com o administrador. |
| 🙋 **Nome do administrador** | `ADMIN_NAME`: "O administrador Fulano atualizou o servidor…". Em branco: "A equipe técnica". |
| 🤖 **Sem trabalho extra** | Detecta sozinho o que você atualiza; ignora o `unattended-upgrades`. |
| 🔕 **Sem repetição** | O estado fica em disco. Reiniciar o serviço ou o servidor não reenvia alertas. |
| 🌎 **Fuso e horário configuráveis** | Padrão: 22:30, `America/Sao_Paulo`. |
| 🛡️ **Resiliente** | Timeouts, novas tentativas, falha em um canal não afeta os outros; falha do `apt` **não** vira "tudo em dia". |
| 🔒 **Seguro por padrão** | Credenciais fora dos logs, `.conf` e banco com `0600`, serviço com hardening do systemd, SMTP sempre sob TLS. |
| 🪶 **Leve** | Uma dependência (`python3-apt`) mais `tzdata`; resto é biblioteca padrão (o SQLite já vem no Python). |

## Como funciona

```mermaid
flowchart LR
    APT[apt / dpkg] -->|listas novas, pacotes instalados| P((APT Monitor Plus))
    P -->|"na hora"| ADM[🛠️ Administradores<br/>Telegram · E-mail]
    P -->|"1 vez por dia"| CLI[🧑‍💼 Cliente<br/>Telegram · E-mail]
    P --- DB[(history.db)]
```

1. O Plus vigia o apt e avisa **os administradores** assim que há atualização disponível.
2. Quando o administrador atualiza, o Plus lê o `history.log` do apt, confere o resultado de cada pacote no
   `dpkg.log` e guarda tudo no histórico.
3. Uma vez por dia, no horário configurado, o **cliente** recebe o resumo do que foi feito (e as pendências antigas).

Detalhes técnicos: [Como funciona](docs/arquitetura.md).

## Instalação

### Pelo `.deb` (recomendado)

Baixe o arquivo mais recente em **[Releases](https://github.com/AprendendoLinux/apt-monitor-daemon/releases?q=plus-v)**
(procure as versões `plus-v…`; há também o `SHA256SUMS`):

```bash
wget https://github.com/AprendendoLinux/apt-monitor-daemon/releases/download/plus-v1.0.0/apt-monitor-plus_1.0-1_all.deb
sha256sum -c SHA256SUMS --ignore-missing          # opcional: confere a integridade
sudo apt install ./apt-monitor-plus_1.0-1_all.deb
```

O pacote cria `/var/lib/apt-monitor-plus`, protege o `.conf` (`0600`), configura o `logrotate` e **habilita** o serviço.
Ele só **inicia** quando a configuração é válida; enquanto for o modelo de exemplo, mostra o que falta.

### Já uso o APT Monitor clássico

Instale o Plus **por cima**: o `apt` remove o clássico e o instalador **migra a sua configuração e o estado** sozinho.
Veja a [migração](docs/migracao.md).

### Gerando o pacote você mesmo

```bash
git clone https://github.com/AprendendoLinux/apt-monitor-daemon && cd apt-monitor-daemon
plus/build.sh                                  # → plus/dist/apt-monitor-plus_<versão>_all.deb
sudo apt install ./plus/dist/apt-monitor-plus_*_all.deb
```

## Início rápido

```bash
# 1. configure os ADMINISTRADORES (Telegram e/ou e-mail)
sudo nano /etc/apt-monitor-plus/apt-monitor.conf

# 2. valide (não envia nada) e teste o envio
sudo apt-monitor-plus --check-config
sudo apt-monitor-plus --test-notify

# 3. ligue
sudo systemctl restart apt-monitor-plus

# 4. (opcional) configure o CLIENTE e pré-visualize o relatório
sudo apt-monitor-plus --report --dry-run
```

O mínimo para funcionar é um canal de administrador:

```ini
[Telegram]
BOT_TOKEN=123456789:AAE-abc...
CHAT_IDS=12345678
```

Passo a passo completo: [Guia de uso](docs/uso.md). Cliente: [Configuração do cliente](docs/cliente.md).

## Configuração

Um único arquivo: **`/etc/apt-monitor-plus/apt-monitor.conf`**. Depois de editar:
`sudo systemctl reload apt-monitor-plus`.

| Seção | Para quê |
|---|---|
| `[Telegram]` | Bot dos **administradores** (token e chats) |
| `[Email]` | E-mail dos **administradores** (SMTP e destinatários) |
| `[Monitor]` | Intervalo de checagem, lembrete, "servidor em dia", `apt update`, log e estado |
| `[Report]` | Relatório do cliente: `ADMIN_NAME`, `REPORT_TIME`, `REPORT_TIMEZONE`, `PENDING_ALERT_DAYS`, `SEND_EMPTY`, `PACKAGE_LIST`, `DB_FILE` |
| `[ClientTelegram]` | Bot do **cliente** (diferente do dos administradores) |
| `[ClientEmail]` | E-mail do **cliente** (mesmas chaves de `[Email]`) |

Exemplo completo (administradores e cliente, Telegram e e-mail):

```ini
[Telegram]
BOT_TOKEN=123456789:AAE-admin...
CHAT_IDS=12345678

[Email]
SMTP_SERVER=smtp.exemplo.com
SMTP_USER=alerta@exemplo.com
SMTP_PASS=sua-senha
RECIPIENT_EMAILS=admin@exemplo.com

[Report]
ADMIN_NAME=Henrique Fagundes
REPORT_TIME=22:30
REPORT_TIMEZONE=America/Sao_Paulo
PENDING_ALERT_DAYS=3

[ClientTelegram]
BOT_TOKEN=987654321:AAF-cliente...
CHAT_IDS=-1009876543210

[ClientEmail]
SMTP_SERVER=smtp.exemplo.com
SMTP_USER=alerta@exemplo.com
SMTP_PASS=sua-senha
SENDER_NAME=Suporte Técnico
RECIPIENT_EMAILS=responsavel@empresa.com.br
```

📄 **Quer ver um arquivo completo, como fica num servidor de verdade?** Veja o
**[exemplo de configuração completa](docs/exemplo-configuracao.md)** (analista e cliente, Telegram e e-mail, com dados
fictícios).

📖 **Todas as chaves, padrões, valores aceitos, erros e exemplos:**
**[Referência de configuração](docs/configuracao.md)**. O modelo completo e comentado também fica em
`/usr/share/doc/apt-monitor-plus/examples/apt-monitor.conf`.

## Uso

| Comando | Função |
|---|---|
| `apt-monitor-plus --check-config` | Valida a configuração e mostra os canais (admin e cliente). Código 78 se inválida. |
| `apt-monitor-plus --test-notify` | Envia uma mensagem de teste a cada canal (relatório de exemplo ao cliente). |
| `apt-monitor-plus --report` | Envia agora o relatório diário ao cliente. |
| `apt-monitor-plus --report --dry-run` | Mostra o relatório sem enviar. |
| `apt-monitor-plus --once` | Faz uma checagem de pendências e sai. |
| `apt-monitor-plus --dry-run` | Mostra os alertas sem enviar nem gravar estado. |
| `apt-monitor-plus -c ARQUIVO` | Usa outro arquivo de configuração. |
| `apt-monitor-plus --version` | Mostra a versão. |

O atalho `apt-monitor` funciona como `apt-monitor-plus`. Manual: `man apt-monitor-plus`.

```bash
systemctl status apt-monitor-plus            # estado do serviço
sudo journalctl -u apt-monitor-plus -f       # logs
sudo systemctl reload apt-monitor-plus       # recarrega o .conf e checa na hora
sudo apt-mark hold <pacote>                  # pacotes em hold são ignorados
```

Todos os detalhes, um dia típico, catálogo de mensagens, logs e backup: **[Guia de uso](docs/uso.md)**.

## O relatório do cliente

- **Uma mensagem por dia**, a partir de `REPORT_TIME` (padrão **22:30**, fuso **America/Sao_Paulo**).
- Diz quantas vezes o administrador atualizou, o total de pacotes, quantos com **sucesso** e quantos com **falha**.
- **Só conta quando há pacote atualizado**; instalar ou remover pacotes não entra, e o `unattended-upgrades` fica de fora.
- **Dia sem novidade, nenhuma mensagem** (ou envie sempre com `SEND_EMPTY=true`).
- **Pendência antiga:** se algum pacote espera há **mais de 3 dias** (`PENDING_ALERT_DAYS`), o relatório lista **todos**
  os pendentes e sugere entrar em contato com o administrador **sem citar nomes**, mesmo em dia sem atualização.
- Cada canal é controlado à parte: se o Telegram entregou e o e-mail falhou, só o e-mail é retentado.

Regras completas: [Relatório diário](docs/relatorio.md). Como configurar: [Configuração do cliente](docs/cliente.md).
Como ficam as mensagens: [Galeria](docs/emails.md).

## Segurança e privacidade

- Token do Telegram e senha SMTP (dos **dois** públicos) são **removidos de qualquer log**, inclusive de erros de rede.
- `/etc/apt-monitor-plus/apt-monitor.conf` e o `history.db` ficam com modo **`0600`**.
- Credenciais SMTP só trafegam **sob TLS** (a menos que você force `SMTP_SECURITY=none`).
- Serviço do systemd com `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`, `PrivateDevices`,
  `RestrictAddressFamilies`, entre outros (`systemd-analyze security apt-monitor-plus`).
- Todo texto dinâmico é **escapado** (HTML); os e-mails **não carregam imagens externas** (sem rastreamento).
- O **cliente nunca vê** os IPs do servidor nem os alertas dos administradores.

Encontrou uma vulnerabilidade? Veja a [política de segurança](../SECURITY.md).

## Compatibilidade

Testado automaticamente (instalação do `.deb`, **migração a partir do clássico**, alertas, relatório, restart, purge) em
contêineres, e com **systemd real** em Debian 12 e Ubuntu 24.04:

| Distribuição | Python | Status |
|---|---|---|
| Debian 11 (bullseye) | 3.9 | ✅ |
| Debian 12 (bookworm) | 3.11 | ✅ (também com systemd) |
| Debian 13 (trixie) | 3.13 | ✅ |
| Ubuntu 20.04 | 3.8 | ✅ |
| Ubuntu 22.04 | 3.10 | ✅ |
| Ubuntu 24.04 | 3.12 | ✅ (também com systemd) |

Os testes unitários foram executados em Python **3.6, 3.8 e 3.12** (o CI roda em 3.8 e 3.12). Derivados (Linux Mint, Raspberry Pi OS, Pop!_OS…) funcionam desde que
tenham `apt`, `python3-apt`, `tzdata` e `systemd`.

## Perguntas frequentes

**Vai atualizar meus pacotes sozinho?** Não. Ele só **avisa** e **registra**. (O máximo que faz no sistema é o
equivalente a `apt update`, e dá para desligar com `UPDATE_CACHE=false`.)

**Os administradores recebem o relatório?** Não. Eles recebem os **alertas** na hora. O relatório é só do cliente.

**Posso usar só Telegram ou só e-mail?** Sim, em cada público: deixe o outro canal vazio.

**Preciso configurar o cliente?** Não. Sem `[ClientTelegram]`/`[ClientEmail]`, o Plus funciona só como alerta para os
administradores, já com a detecção imediata e os e-mails novos.

**Trabalho como root; como o relatório sabe meu nome?** Pela chave `ADMIN_NAME`. O apt só registra `root`.

**Funciona com `unattended-upgrades`?** Sim. As atualizações automáticas **não** entram no relatório (não são trabalho do
administrador), mas os alertas de pendência funcionam normalmente.

**Quanto tempo leva para o alerta chegar?** Cerca de 1 minuto depois que o apt termina de baixar as listas.

**E se o servidor ficar desligado no horário do relatório?** O relatório sai assim que o serviço voltar, no mesmo dia.

**Posso adicionar Discord/Slack/ntfy?** Sim: crie uma classe com `name` e `send(mensagem)`; veja
[a arquitetura](docs/arquitetura.md#estrutura-do-código).

**Dá para voltar ao clássico?** Dá, a qualquer momento: [Migração](docs/migracao.md#voltar-para-o-clássico).

Mais em [Solução de problemas](docs/solucao-de-problemas.md).

## Documentação

| Guia | Para quê |
|---|---|
| [Guia de uso](docs/uso.md) | Instalar, ligar, testar, comandos, um dia típico, mensagens, logs, backup |
| [Referência de configuração](docs/configuracao.md) | **Todas as chaves**, padrões, erros e exemplos prontos |
| [Exemplo de configuração completa](docs/exemplo-configuracao.md) | Um `.conf` real de produção (dados fictícios): analista e cliente, Telegram e e-mail |
| [Configuração do cliente](docs/cliente.md) | Segundo bot, grupo, e-mail, nome do administrador, testes |
| [Relatório diário](docs/relatorio.md) | Regras: o que conta, quando sai, pendências antigas, casos de borda |
| [Galeria de mensagens](docs/emails.md) | Capturas dos e-mails (desktop e celular) |
| [Migração do clássico](docs/migracao.md) | Trocar o clássico pelo Plus, conferir e voltar atrás |
| [Como funciona](docs/arquitetura.md) | Fluxos, banco de dados, tempos, segurança, código |
| [Solução de problemas](docs/solucao-de-problemas.md) | Diagnóstico passo a passo |
| [Criar o bot do Telegram](../docs/telegram.md) · [Configurar o SMTP](../docs/email.md) | Guias compartilhados com o clássico |
| [Changelog do Plus](CHANGELOG.md) | Histórico de versões |

## Desenvolvimento

```bash
python3 -m unittest discover -s plus/tests -v   # unitários (segundos)
plus/build.sh                                    # gera plus/dist/apt-monitor-plus_<versão>_all.deb
plus/tests/docker/run-matrix.sh [imagem...]      # instala o .deb em contêineres Debian/Ubuntu, inclusive a migração
plus/tests/docker/systemd-test.sh [imagem...]    # idem, com systemd real
plus/tests/render/run.sh                         # renderiza os e-mails num Chromium (contêiner) e salva capturas
```

Veja o [guia de contribuição](../CONTRIBUTING.md).

## Licença

[MIT](../LICENSE).
