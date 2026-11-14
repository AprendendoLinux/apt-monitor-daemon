# Changelog

## 1.1.1
- Adiciona a licença MIT (`LICENSE`) e o arquivo `copyright` do pacote no formato Debian.

## 1.1.0

### Segurança
- Token do Telegram e senha SMTP nunca mais aparecem nos logs (filtro de redação).
- `apt-monitor.conf` instalado com permissão `0600`.
- Serviço com hardening do systemd (`ProtectSystem=strict`, `NoNewPrivileges`, etc.).

### Correções
- Falha do apt (rede, lock) não é mais interpretada como "nenhuma atualização".
- Estado persistente (`/var/lib/apt-monitor/state.json`): restart, reboot, upgrade do pacote e
  rotação de log não reenviam mais o mesmo alerta.
- Deduplicação por pacote/versão (e não pela contagem); alerta só quando surge algo novo.
- Alerta que falhou em todos os canais é retentado (não é mais dado como enviado).
- Timeouts e novas tentativas no Telegram e no SMTP; falha em um destinatário não afeta os demais.
- Parser de configuração aceita comentários no fim da linha e senhas com `%`.
- `BOT_TOKEN` aceita com ou sem o prefixo `bot`.
- Telegram em HTML com escape; e-mail com escape, `Date`, `Message-ID` e parte `text/plain`.
- "Crítico" só para imagem de kernel/metapacotes (headers e firmware não disparam mais).
- Pacotes em `hold` são ignorados.
- logrotate sem restart do serviço (log reaberto automaticamente).

### Novidades
- Destaque de atualizações de segurança; aviso de reinicialização pendente (`reboot-required`).
- `REMINDER_DAYS`, `NOTIFY_ON_CLEAR`, `UPDATE_CACHE`, `IGNORE_INTERFACES`, `SMTP_SECURITY`, `API_BASE`.
- Recarga da configuração com `systemctl reload` (SIGHUP).
- CLI: `--check-config`, `--test-notify`, `--once`, `--dry-run`.
- Sem dependência de `python3-requests` (usa só a biblioteca padrão).
- Script movido para `/usr/lib/apt-monitor`, comando `apt-monitor` em `/usr/sbin`, unit em `/usr/lib/systemd/system`.
- `postinst` só inicia o serviço se a configuração for válida; `postrm` limpa estado/log no `purge`.
- Build reproduzível (`build.sh`), testes automatizados, CI e documentação completa (`docs/`).

## 1.0
- Versão inicial.
