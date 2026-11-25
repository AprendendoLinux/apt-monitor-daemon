# Migração: do APT Monitor clássico para o Plus

O **Plus substitui** o clássico no servidor: instala-se o pacote `apt-monitor-plus`, e o `apt-monitor` é removido
automaticamente. A sua **configuração e o estado são migrados sozinhos**, então os alertas continuam como estavam,
sem repetir o que já foi avisado.

## Índice

- [Resumo](#resumo)
- [Passo a passo](#passo-a-passo)
- [O que acontece por baixo](#o-que-acontece-por-baixo)
- [Como conferir](#como-conferir)
- [O que mudou entre as edições](#o-que-mudou-entre-as-edições)
- [Voltar para o clássico](#voltar-para-o-clássico)
- [Limpar o que sobrou do clássico](#limpar-o-que-sobrou-do-clássico)
- [Perguntas frequentes](#perguntas-frequentes)

---

## Resumo

| | |
|---|---|
| Comando | `sudo apt install ./apt-monitor-plus_1.0-1_all.deb` |
| O clássico | É **removido** pelo próprio `apt` (os dois pacotes são incompatíveis, para nunca haver alerta duplicado). |
| Configuração | **Copiada** de `/etc/apt-monitor/apt-monitor.conf` para `/etc/apt-monitor-plus/apt-monitor.conf`. |
| Estado dos alertas | **Copiado** de `/var/lib/apt-monitor/state.json`: nada é reenviado. |
| Serviço | `apt-monitor.service` é parado e desabilitado; `apt-monitor-plus.service` é habilitado e iniciado. |
| Tempo fora do ar | Segundos. |

## Passo a passo

```bash
# 1. baixe o pacote do Plus (página de Releases, tags "plus-v…")
wget https://github.com/AprendendoLinux/apt-monitor-daemon/releases/download/plus-v1.0.0/apt-monitor-plus_1.0-1_all.deb

# 2. instale (o apt remove o apt-monitor clássico e instala o Plus)
sudo apt install ./apt-monitor-plus_1.0-1_all.deb
```

O `apt` avisa que vai **remover `apt-monitor`**: é o esperado. Durante a instalação você verá:

```text
apt-monitor-plus: configuração do apt-monitor migrada para /etc/apt-monitor-plus/apt-monitor.conf.
apt-monitor-plus: estado anterior migrado (alertas já enviados não se repetem).
```

Depois, confira (veja [Como conferir](#como-conferir)) e, se quiser, ative o relatório do cliente
([guia do cliente](cliente.md)).

## O que acontece por baixo

1. O `apt` remove o `apt-monitor`. O `prerm` dele **para e desabilita** o serviço antigo. A configuração e o estado do
   clássico **permanecem no disco** (o pacote fica "removido, com configuração").
2. O Plus é instalado, com **caminhos próprios**:

   | | Clássico | Plus |
   |---|---|---|
   | Pacote | `apt-monitor` | `apt-monitor-plus` |
   | Serviço | `apt-monitor.service` | `apt-monitor-plus.service` |
   | Configuração | `/etc/apt-monitor/apt-monitor.conf` | `/etc/apt-monitor-plus/apt-monitor.conf` |
   | Estado | `/var/lib/apt-monitor/state.json` | `/var/lib/apt-monitor-plus/state.json` |
   | Histórico | — | `/var/lib/apt-monitor-plus/history.db` |
   | Log | `/var/log/apt-monitor.log` | `/var/log/apt-monitor-plus.log` |
   | Comando | `apt-monitor` | `apt-monitor-plus` (e o atalho `apt-monitor`) |
   | Manual | `man apt-monitor` | `man apt-monitor-plus` |

3. O `postinst` do Plus, **apenas na primeira instalação** e **só se** o `.conf` do Plus ainda for o modelo de exemplo:
   - copia o seu `.conf` do clássico para o do Plus (modo `0600`) e **acrescenta**, comentadas, as seções novas do
     Plus (`[Report]`, `[ClientTelegram]`, `[ClientEmail]`);
   - copia o `state.json` (se existir), para não reenviar alertas já avisados;
   - habilita e inicia o serviço do Plus.

> **Por que caminhos separados?** Se o Plus usasse os mesmos arquivos do clássico, um futuro `apt purge apt-monitor`
> (para "limpar o que sobrou") apagaria o histórico e o estado do Plus. Com caminhos próprios isso é impossível: cada
> pacote só mexe nos seus arquivos.

## Como conferir

```bash
systemctl status apt-monitor-plus            # ativo (running)
systemctl status apt-monitor                 # deve dizer que a unit não existe / inativa
apt-monitor-plus --version                   # apt-monitor-plus 1.0.0
sudo apt-monitor-plus --check-config         # Configuração OK + canais ativos
sudo apt-monitor-plus --test-notify          # recebe a mensagem de teste?
sudo grep -c . /etc/apt-monitor-plus/apt-monitor.conf   # o arquivo foi migrado
ls -l /var/lib/apt-monitor-plus/             # state.json (e history.db depois que o serviço rodar)
```

Se o `.conf` migrado ainda estiver com valores de exemplo, o serviço não inicia e o instalador explica o que falta.

## O que mudou entre as edições

| | Clássico | **Plus** |
|---|---|---|
| Alertas aos administradores (Telegram e e-mail) | ✅ | ✅ |
| **Alerta imediato** quando o apt muda (≈ 1 min), sem esperar o intervalo | — | ✅ |
| **E-mails** dos alertas | Simples | Novos: cabeçalho por gravidade, cartões, selos, comando sugerido, celular |
| **Relatório diário ao cliente** (Telegram e/ou e-mail) | — | ✅ |
| **Aviso de pendência antiga** (mais de N dias) ao cliente | — | ✅ |
| Histórico do que foi atualizado, com sucesso/falha por pacote | — | ✅ (SQLite) |
| `--report` | — | ✅ |
| Dependências | `python3-apt` | `python3-apt` + `tzdata` |

As chaves de `[Telegram]`, `[Monitor]` e `[Email]` **são as mesmas**; o Plus apenas acrescenta seções e mantém os
mesmos padrões. Quem não configurar o cliente tem o comportamento de alertas de sempre, com e-mails mais bonitos
e a detecção mais rápida.

## Voltar para o clássico

Possível a qualquer momento:

```bash
wget https://github.com/AprendendoLinux/apt-monitor-daemon/releases/download/v1.1.1/apt-monitor_1.1.1-1_all.deb
sudo apt install ./apt-monitor_1.1.1-1_all.deb    # o apt remove o Plus e reinstala o clássico
```

- A configuração do clássico (`/etc/apt-monitor/apt-monitor.conf`) ainda está lá, **como era antes da migração**.
  Se você mudou algo depois no `.conf` do Plus e quer levar junto, copie:

  ```bash
  sudo cp /etc/apt-monitor-plus/apt-monitor.conf /etc/apt-monitor/apt-monitor.conf
  ```

  O clássico simplesmente **ignora** as seções que não conhece (`[Report]`, `[ClientTelegram]`, `[ClientEmail]`).
- O histórico do Plus (`history.db`) fica guardado em `/var/lib/apt-monitor-plus/` enquanto você não fizer `purge`.

## Limpar o que sobrou do clássico

Depois de migrar, o `apt` lista `apt-monitor` como "removido, com configuração residual". É inofensivo, e dá para
limpar com segurança (**não** toca nos arquivos do Plus):

```bash
sudo apt purge apt-monitor
```

Isso apaga `/etc/apt-monitor`, `/var/lib/apt-monitor` e `/var/log/apt-monitor.log`. Antes, confirme que o Plus está
funcionando com a configuração migrada.

## Perguntas frequentes

**Posso ter os dois instalados na mesma máquina?** Não: o `apt` não deixa (conflito declarado), e não faria sentido,
porque cada um mandaria o seu alerta. Em **máquinas diferentes** você pode usar edições diferentes, sem problema.

**Vou receber de novo o alerta que já recebi?** Não: o estado foi copiado. Se não houver `state.json` para migrar,
o Plus avisa as pendências atuais uma vez, como numa instalação nova.

**O `dpkg` perguntou algo sobre arquivos de configuração.** Em **atualizações do próprio Plus**, responda **N** (manter
o seu). Na migração a partir do clássico isso não acontece, porque os arquivos são diferentes.

**E se eu já tinha o `/etc/apt-monitor-plus/apt-monitor.conf` configurado?** A migração só copia o do clássico quando o
do Plus ainda é o modelo de exemplo; um `.conf` do Plus já preenchido nunca é sobrescrito.

**Preciso mudar scripts que chamam `apt-monitor`?** Não: o atalho `/usr/sbin/apt-monitor` continua existindo e aponta
para o Plus. Referências ao serviço `apt-monitor.service` (por exemplo, em monitoramento) devem passar a usar
`apt-monitor-plus.service`.
