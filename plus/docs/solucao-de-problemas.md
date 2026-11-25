# Solução de problemas

Comece sempre por aqui:

```bash
systemctl status apt-monitor-plus
sudo journalctl -u apt-monitor-plus -n 50 --no-pager
sudo tail -n 50 /var/log/apt-monitor-plus.log
sudo apt-monitor-plus --check-config
```

## Índice

**Instalação e serviço**
- [O serviço não inicia depois da instalação](#o-serviço-não-inicia-depois-da-instalação)
- [`--check-config` sai com código 78](#--check-config-sai-com-código-78)
- [O `apt` quer remover o `apt-monitor` ao instalar o Plus](#o-apt-quer-remover-o-apt-monitor-ao-instalar-o-plus)

**Alertas dos administradores**
- [Não chega nenhum alerta](#não-chega-nenhum-alerta)
- [O alerta demorou](#o-alerta-demorou)
- [Recebi o mesmo alerta duas vezes](#recebi-o-mesmo-alerta-duas-vezes)
- [Telegram: HTTP 401, 400 ou 403](#telegram-http-401-400-ou-403)
- [E-mail: falha de conexão, STARTTLS ou autenticação](#e-mail-falha-de-conexão-starttls-ou-autenticação)

**Relatório do cliente**
- [O cliente não recebeu o relatório](#o-cliente-não-recebeu-o-relatório)
- [Atualizei o servidor e não apareceu no relatório](#atualizei-o-servidor-e-não-apareceu-no-relatório)
- [Os pacotes aparecem "com falha", mas foram instalados](#os-pacotes-aparecem-com-falha-mas-foram-instalados)
- [O aviso de pendência antiga não aparece](#o-aviso-de-pendência-antiga-não-aparece)
- [O horário do relatório está errado](#o-horário-do-relatório-está-errado)
- [Quero reenviar ou antecipar o relatório](#quero-reenviar-ou-antecipar-o-relatório)

**Outros**
- [Perdi o histórico / quero recomeçar](#perdi-o-histórico--quero-recomeçar)
- [Como ver o que o Plus está lendo](#como-ver-o-que-o-plus-está-lendo)

---

## O serviço não inicia depois da instalação

**É esperado** enquanto o `.conf` ainda tem os valores de exemplo (`seu_bot_token_aqui`…): o pacote só inicia o
serviço quando a configuração é válida. Edite `/etc/apt-monitor-plus/apt-monitor.conf`, valide e inicie:

```bash
sudo apt-monitor-plus --check-config
sudo systemctl restart apt-monitor-plus
```

## `--check-config` sai com código 78

A mensagem antes do código diz o que está errado. A lista completa está em
[Validação e mensagens de erro](configuracao.md#validação-e-mensagens-de-erro). A causa mais comum é
`Nenhum canal de notificação válido`: nenhum canal de **administrador** (`[Telegram]`/`[Email]`) está preenchido com
valores reais. Só os canais do cliente **não bastam**.

## O `apt` quer remover o `apt-monitor` ao instalar o Plus

É o esperado: o Plus **substitui** o clássico. Sua configuração e seu estado são migrados. Veja
[Migração](migracao.md).

---

## Não chega nenhum alerta

1. **Há pendências mesmo?** `apt list --upgradable`. Pacotes em `hold` (`apt-mark showhold`) são ignorados.
2. **O Plus já avisou essas?** Ele só alerta quando surge pacote **ou versão novos**. Para ver o que ele faria agora:
   `sudo apt-monitor-plus --dry-run`.
3. **O canal funciona?** `sudo apt-monitor-plus --test-notify` mostra `OK` ou `FALHOU` para cada canal.
4. **O log diz o quê?** Procure `Nenhum canal conseguiu enviar` ou erros de Telegram/SMTP.
5. Quer avisar de novo as pendências atuais? Com o serviço parado, apague o estado e reinicie:

   ```bash
   sudo systemctl stop apt-monitor-plus
   sudo rm /var/lib/apt-monitor-plus/state.json
   sudo systemctl start apt-monitor-plus
   ```

## O alerta demorou

O alerta sai **em cerca de 1 minuto** depois que o apt termina de baixar as listas. Se demorou muito mais:

- O `apt update` pode estar sendo feito por algo que **não mexe** em `/var/lib/apt/lists` (um espelho que não mudou
  nada): então não há novidade e o alerta só sai na próxima checagem completa (`CHECK_INTERVAL_HOURS`).
- O `apt` pode estar ocupado (`apt update` longo): o Plus espera ele ficar 20 s quieto.
- Procure no log a linha `O apt mudou as listas/pacotes; checando atualizações agora.`
- Se o `apt` falhou (rede, lock), a checagem é ignorada e repetida em até 15 minutos.

## Recebi o mesmo alerta duas vezes

Só deve acontecer se você apagou o `state.json`, se saiu uma **versão nova** de algum pacote, ou se você tem **dois
programas** avisando (por exemplo, o clássico e o Plus em máquinas diferentes apontando para o mesmo chat).
Reiniciar o serviço, reiniciar o servidor e atualizar o Plus **não** repetem alertas.

## Telegram: HTTP 401, 400 ou 403

| Erro | Causa |
|---|---|
| `HTTP 401: Unauthorized` | Token errado ou revogado. Confira em `@BotFather` → `/mybots`. |
| `HTTP 400: Bad Request: chat not found` | `chat_id` errado, ou a pessoa nunca falou com o bot (um bot não inicia conversa). Peça `/start`. |
| `HTTP 403: Forbidden: bot was blocked by the user` | A pessoa bloqueou o bot. |
| `HTTP 403: bot is not a member of the group chat` | O bot não está no grupo. |
| `HTTP 429` | Limite do Telegram: o Plus espera e tenta de novo sozinho. |

Como obter token e `chat_id`: [guia do Telegram](../../docs/telegram.md).

## E-mail: falha de conexão, STARTTLS ou autenticação

| Mensagem no log | Causa |
|---|---|
| `Falha ao conectar no SMTP …` | Servidor/porta errados, bloqueio de firewall ou DNS. Teste: `nc -vz servidor 587`. |
| `o servidor não oferece STARTTLS; recusando enviar credenciais sem criptografia` | Com `SMTP_SECURITY=auto` e usuário/senha, o Plus **não** envia senha sem TLS. Use a porta `465` (`ssl`) ou `587` (`starttls`); se for um relay local confiável, use `SMTP_SECURITY=none` e deixe `SMTP_USER` vazio. |
| `Authentication failed` / `535` | Usuário ou senha errados. No Gmail, use *senha de app*. |
| `Falha ao enviar e-mail para …` | Aquele destinatário foi recusado; os outros continuam recebendo. |

Mais em [guia de e-mail](../../docs/email.md). Lembre: `[Email]` é dos **administradores**; o do cliente é `[ClientEmail]`.

---

## O cliente não recebeu o relatório

Passe pela lista, na ordem:

1. **O cliente está configurado?** `sudo apt-monitor-plus --check-config` deve mostrar
   `Relatório ao cliente: telegram, email` (ou o canal que você usa), e **não** `desativado`.
2. **Havia o que reportar?** O relatório só sai se, desde o último, houve **atualização** feita pelo administrador
   **ou** há pendência antiga. Dia calmo = nenhuma mensagem (a menos que `SEND_EMPTY=true`).
3. **Já passou do horário?** `REPORT_TIME` e `REPORT_TIMEZONE` (padrão 22:30, São Paulo). Veja o
   [horário errado](#o-horário-do-relatório-está-errado).
4. **O canal funciona?** `sudo apt-monitor-plus --test-notify` envia um teste ao cliente.
5. **Pré-visualize:** `sudo apt-monitor-plus --report --dry-run` mostra o relatório com os dados desta máquina.
6. **Veja o log:** `O relatório diário não chegou por todos os canais` indica falha de entrega (nova tentativa a cada
   15 min só no canal que falhou).
7. **Já foi enviado hoje?** Um `--report` manual conta como o relatório do dia.

## Atualizei o servidor e não apareceu no relatório

- Foi **só instalação** (`apt install`) ou remoção? Só execuções com **atualização de pacotes** (`Upgrade:`) contam.
- Foi o **`unattended-upgrades`**? Ele é ignorado de propósito.
- A atualização foi feita **antes** de o Plus ser instalado? O histórico só vale a partir da criação do banco.
- O serviço estava **parado** na hora? Ao voltar, o Plus lê o `history.log` e registra o que ficou para trás (desde que
  seja posterior à criação do banco).
- Foi **depois do horário do relatório**? Entra no relatório do dia seguinte.
- Confira o que o Plus vê: [Como ver o que o Plus está lendo](#como-ver-o-que-o-plus-está-lendo).

## Os pacotes aparecem "com falha", mas foram instalados

O Plus conta como sucesso o pacote que o `dpkg.log` mostra como `installed` **na versão nova** (ou, sem log, que o
`dpkg-query` mostra instalado com versão igual ou maior). Pode dar "falha" quando:

- A atualização foi **interrompida** ou o `dpkg` ficou em estado intermediário (`half-configured`).
- O `/var/log/dpkg.log` está **truncado ou desativado** e o `dpkg-query` não confirma a versão.

Confira com `dpkg -l <pacote>` e `grep " status installed <pacote> " /var/log/dpkg.log`.

## O aviso de pendência antiga não aparece

- **`PENDING_ALERT_DAYS=0`?** Desativa o aviso.
- **Ainda não passou o prazo.** A contagem é desde que o Plus **viu** o pacote pendente e exige **mais de** N dias.
  Logo depois da instalação, nada aparece até `PENDING_ALERT_DAYS` dias de funcionamento.
- **O pacote foi instalado e voltou?** A contagem recomeça.
- **Nenhum canal do cliente configurado?** Sem canal de cliente, nada é enviado.
- O aviso só é avaliado **no horário do relatório**, uma vez por dia.

## O horário do relatório está errado

- Confira `REPORT_TIME` e `REPORT_TIMEZONE`. O horário vale **no fuso configurado**, não no do servidor.
- Hora do servidor: `timedatectl`. Nome do fuso válido: `ls /usr/share/zoneinfo/America/Sao_Paulo`.
- Depois de mudar: `sudo systemctl reload apt-monitor-plus`.

## Quero reenviar ou antecipar o relatório

```bash
sudo apt-monitor-plus --report
```

Envia agora o que ainda não foi reportado. Se o relatório do dia **já foi enviado** e não há nada novo, o comando diz
que não há o que reportar. Para **testar o visual** sem consumir os dados, use `--test-notify` ou
`--report --dry-run`.

---

## Perdi o histórico / quero recomeçar

```bash
sudo systemctl stop apt-monitor-plus
sudo rm /var/lib/apt-monitor-plus/history.db
sudo systemctl start apt-monitor-plus
```

O histórico recomeça "a partir de agora" e a contagem de dias das pendências também. O passado **não** é reenviado.

## Como ver o que o Plus está lendo

```bash
# as execuções do apt que contam como atualização
sudo grep -B3 -A3 '^Upgrade:' /var/log/apt/history.log

# o resultado de cada pacote
sudo grep ' status installed ' /var/log/dpkg.log | tail

# o que o Plus já registrou
sudo python3 - <<'EOF'
import sqlite3
db = sqlite3.connect('/var/lib/apt-monitor-plus/history.db')
for row in db.execute("select id, datetime(start_ts,'unixepoch'), ok, failed, reported_day from runs"):
    print(row)
EOF
```
