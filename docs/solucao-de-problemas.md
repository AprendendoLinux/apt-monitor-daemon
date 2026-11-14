# Solução de problemas

Comece sempre por:

```bash
sudo apt-monitor --check-config      # a configuração é válida?
sudo apt-monitor --test-notify       # os canais entregam?
sudo apt-monitor --dry-run           # o que seria enviado agora?
sudo journalctl -u apt-monitor -n 50 # o que o serviço diz?
```

## O serviço não iniciou depois da instalação

Esperado quando a configuração ainda tem os valores de exemplo. O `postinst` só inicia o serviço com configuração
válida. Edite `/etc/apt-monitor/apt-monitor.conf`, rode `--check-config` e então
`sudo systemctl restart apt-monitor`.

## `Nenhum canal de notificação válido` / serviço em `failed` com status 78

Nem Telegram nem e-mail estão configurados de verdade (valores como `seu_bot_token_aqui` ou `smtp.seuservidor.com`
são tratados como vazios). Corrija o `.conf`. Depois: `sudo systemctl reset-failed apt-monitor && sudo systemctl start apt-monitor`.

## Telegram: `HTTP 401` / `HTTP 404`

Token errado ou revogado. Confira com `curl https://api.telegram.org/bot<TOKEN>/getMe`.

## Telegram: `HTTP 400 - chat not found`

O `chat_id` está errado, ou você ainda não enviou nenhuma mensagem ao bot (ou não o adicionou ao grupo).
Veja [docs/telegram.md](telegram.md).

## Telegram: `HTTP 403 - bot was blocked` / `bot was kicked`

O usuário bloqueou o bot ou ele foi removido do grupo. Desbloqueie/readicione.

## E-mail: `o servidor não oferece STARTTLS; recusando enviar credenciais`

O servidor não suporta STARTTLS na porta escolhida. Use a porta/modo corretos (`465` + `ssl` ou `587` + `starttls`).
Só use `SMTP_SECURITY=none` em relays locais confiáveis.

## E-mail: `Authentication failed` / `535`

Senha errada, ou o provedor exige *senha de app* (Gmail) / *SMTP AUTH* habilitado (Microsoft 365).
Veja [docs/email.md](email.md).

## E-mail chega, mas cai em spam

Use um `SENDER_EMAIL` do mesmo domínio do servidor SMTP e confira SPF/DKIM do domínio.

## `Não foi possível atualizar as listas do APT ... usando a lista local`

O `apt update` interno falhou (repositório fora do ar, lock do `unattended-upgrades`, sem rede). O daemon segue com
a lista local e tenta de novo no próximo ciclo. Se você já atualiza as listas por outro meio, use `UPDATE_CACHE=false`.

## Quero um alerta de novo (reset)

```bash
sudo systemctl stop apt-monitor
sudo rm /var/lib/apt-monitor/state.json
sudo systemctl start apt-monitor
```

## Recebi alerta de um pacote que eu não quero

Pacotes em `hold` são ignorados: `sudo apt-mark hold <pacote>`.

## O alerta mostra IPs de Docker/VMs

Ajuste `IGNORE_INTERFACES` (curingas permitidos), por exemplo `IGNORE_INTERFACES=lo,docker*,br-*,veth*,virbr*,wg*`.

## `Permission denied` ao rodar `apt-monitor` como usuário comum

O `.conf` é `0600` (root). Use `sudo`.

## Alterei o `.conf` e nada mudou

`sudo systemctl reload apt-monitor` (recarrega e já faz uma checagem) ou `sudo systemctl restart apt-monitor`.

## Atualizei da v1.0 e o `dpkg` perguntou sobre o `.conf`

Responda **N** (manter o seu). As chaves novas têm valores padrão. Compare com o novo exemplo em
`/etc/apt-monitor/apt-monitor.conf.dpkg-dist` se quiser adotar as novidades.

## Funciona no Raspberry Pi OS / Linux Mint / outros derivados?

Sim, desde que tenham `apt`, `python3-apt` e `systemd`.
