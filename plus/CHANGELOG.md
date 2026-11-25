# Changelog — APT Monitor Plus

O Plus tem **versões próprias**, independentes do APT Monitor clássico (`CHANGELOG.md` na raiz do repositório).
Tags de release: `plus-vX.Y.Z`.

## 1.0.0

Primeira versão da edição **Plus**. Ela parte do núcleo do APT Monitor clássico 1.1.1 (alertas de atualização, kernel,
segurança, reinício pendente, estado persistente, hardening) e acrescenta:

### Para os administradores
- **Alerta imediato**: além do intervalo (`CHECK_INTERVAL_HOURS`), o daemon observa `/var/lib/apt/lists` e
  `/var/lib/dpkg/status` e refaz a checagem em cerca de 1 minuto quando o apt muda as listas ou instala pacotes, sem
  novo `apt update`. O `apt update` do próprio daemon não dispara essa checagem.
- **E-mails de alerta novos**: cabeçalho por gravidade (crítico, segurança, comum), cartões de totais, selos de
  **Kernel** e **Segurança** por pacote, comando sugerido (`sudo apt update && sudo apt upgrade`), horário da detecção e
  layout para celular. Sem imagens externas.

### Para o cliente (novo)
- **Relatório diário** por um segundo bot do Telegram (`[ClientTelegram]`) e/ou por e-mail HTML (`[ClientEmail]`): quantas
  vezes o administrador atualizou o servidor e o total de pacotes, com sucesso e com falha.
- Sai **uma vez por dia**, a partir de `REPORT_TIME` (padrão 22:30) no fuso `REPORT_TIMEZONE` (padrão
  `America/Sao_Paulo`). Dia sem novidade não gera mensagem (`SEND_EMPTY=true` muda isso). Cada canal é controlado à
  parte; falhas são retentadas sem reenviar aos canais que já receberam.
- **Pendências antigas**: se algum pacote espera instalação há **mais de** `PENDING_ALERT_DAYS` dias (padrão 3), o
  relatório lista **todos** os pendentes, com a idade de cada um, e sugere entrar em contato com o administrador (sem
  citar nomes). Vale também para dias sem atualização e se repete diariamente até a instalação.
- `ADMIN_NAME`: "O administrador Fulano atualizou o servidor…" (em branco: "A equipe técnica").
- O cliente **nunca** recebe IPs nem alertas dos administradores. `PACKAGE_LIST=false` oculta a tabela de pacotes.

### Histórico
- O daemon lê o `/var/log/apt/history.log` (inclusive o girado, `.1.gz`) e registra cada execução com **atualização de
  pacotes**; instalar/remover não conta, e o `unattended-upgrades` é ignorado.
- **Sucesso ou falha por pacote**, confirmado no `dpkg.log` (ou no `dpkg-query`).
- Banco SQLite em `/var/lib/apt-monitor-plus/history.db` (`0600`); só registra o que acontece **depois** da criação do
  banco.

### Comandos e empacotamento
- `--report` (envia agora; com `--dry-run`, só pré-visualiza). `--test-notify` também testa os canais do cliente e
  `--check-config` mostra os canais de administrador e de cliente.
- Pacote **`apt-monitor-plus`**, com caminhos próprios (`/etc/apt-monitor-plus`, `/var/lib/apt-monitor-plus`,
  `apt-monitor-plus.service`) e o atalho `apt-monitor`.
- **Substitui o `apt-monitor` clássico** (`Conflicts`/`Replaces`) e **migra sozinho** a configuração e o estado dele
  (veja `docs/migracao.md`).
- Depende de `tzdata` (validação do fuso do relatório).
- Documentação completa em `plus/docs/`: referência de configuração, guia de uso, configuração do cliente, regras do
  relatório, galeria de e-mails, migração, arquitetura e solução de problemas.
- E-mails conferidos num navegador de verdade (Chromium em contêiner), no desktop e no celular
  (`plus/tests/render/`).
