#!/bin/bash
# Roda DENTRO do container (Debian/Ubuntu). /work = raiz do repositório, com dist/*.deb já construído.
set -euo pipefail
. /work/tests/docker/lib.sh
. /etc/os-release; echo "=== $PRETTY_NAME | $(python3 --version 2>&1) ==="
DEB=$(ls /work/dist/apt-monitor_*_all.deb)

step "Dependências e repositórios locais de teste"
if [ "${VERSION_CODENAME:-}" = bullseye ]; then   # Debian 11 já saiu dos mirrors padrão
  printf 'deb http://archive.debian.org/debian bullseye main\ndeb http://archive.debian.org/debian-security bullseye-security main\n' > /etc/apt/sources.list
  echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99archive
  rm -f /etc/apt/sources.list.d/*
fi
apt-get update -qq >/dev/null
apt-get install -y -qq python3-apt apt-utils iproute2 ca-certificates dpkg-dev python3-requests >/dev/null
mkdir /etc/apt/disabled
mv /etc/apt/sources.list /etc/apt/disabled/ 2>/dev/null || true
mv /etc/apt/sources.list.d/* /etc/apt/disabled/ 2>/dev/null || true

for p in demo-a demo-sec demo-held linux-image-demo; do mkpkg $p 1.0 /srv/base; done
mkrepo /srv/base demo
apt-get update -qq >/dev/null
apt-get install -y -qq demo-a demo-sec demo-held linux-image-demo >/dev/null
mkpkg demo-sec 2.0 /srv/sec;  mkrepo /srv/sec demo-security
for p in demo-a demo-held linux-image-demo; do mkpkg $p 2.0 /srv/upd; done; mkrepo /srv/upd demo-updates
apt-mark hold demo-held >/dev/null
apt-get update -qq >/dev/null
ok "3 pacotes atualizáveis + 1 em hold, 1 deles vindo de um repositório '-security'"

step "Migração: instala a v1.0 (do histórico do git) e atualiza para a nova"
printf '#!/bin/sh\nexit 0\n' > /usr/bin/systemctl; chmod +x /usr/bin/systemctl      # 1.0 chama systemctl sem checar
apt-get install -y -qq /work/tests/docker/apt-monitor_1.0-1_all.deb >/dev/null
[ -f /opt/apt-monitor/apt_monitor.py ] || die "1.0 não instalou"
sed -i 's/^CHECK_INTERVAL_HOURS=.*/CHECK_INTERVAL_HOURS=1/' /etc/apt-monitor/apt-monitor.conf   # conf "personalizado"
rm /usr/bin/systemctl
apt-get install -y -qq -o Dpkg::Options::=--force-confold "$DEB" >/dev/null
[ ! -e /opt/apt-monitor ] && ok "/opt/apt-monitor removido" || die "/opt antigo ficou"
grep -q '^CHECK_INTERVAL_HOURS=1' /etc/apt-monitor/apt-monitor.conf && ok "conf do administrador preservado" || die "conf sobrescrito"

step "Arquivos instalados"
[ "$(stat -c %a /etc/apt-monitor/apt-monitor.conf)" = 600 ] && ok "conf com modo 600" || die "modo do conf: $(stat -c %a /etc/apt-monitor/apt-monitor.conf)"
[ "$(stat -c %a /var/lib/apt-monitor)" = 750 ] && ok "/var/lib/apt-monitor 750" || die "modo do state dir"
apt-monitor --version
[ -f /usr/lib/systemd/system/apt-monitor.service ] && ok "unit em /usr/lib/systemd/system" || die "sem unit"

step "Configuração de exemplo (placeholders) é rejeitada com EX_CONFIG"
cp /etc/apt-monitor/apt-monitor.conf /tmp/conf.orig
cat > /tmp/placeholder.conf <<'EOC'
[Telegram]
BOT_TOKEN=seu_bot_token_aqui
CHAT_IDS=12345678, 87654321
[Email]
SMTP_SERVER=smtp.seuservidor.com
RECIPIENT_EMAILS=admin@seuservidor.com
EOC
rc=0; apt-monitor -c /tmp/placeholder.conf --check-config >/dev/null 2>&1 || rc=$?
[ "$rc" = 78 ] && ok "exit 78" || die "esperava 78, veio $rc"

step "Configuração real apontando para Telegram/SMTP falsos"
python3 /work/tests/docker/mock_servers.py & MOCK=$!
cat > /etc/apt-monitor/apt-monitor.conf <<'EOC'
[Telegram]
BOT_TOKEN=bot123456789:AAEhBP0av28dEXAMPLEexampleTOKEN_xyz12
CHAT_IDS=111, 222   # dois chats
API_BASE=http://127.0.0.1:8081
[Monitor]
CHECK_INTERVAL_HOURS=4
NOTIFY_ON_CLEAR=true
UPDATE_CACHE=true
[Email]
SMTP_SERVER=127.0.0.1
SMTP_PORT=2525 # relay local
SMTP_SECURITY=none
RECIPIENT_EMAILS=ops@example.com
SENDER_EMAIL=monitor@example.com
EOC
sleep 1
apt-monitor --check-config >/dev/null && ok "--check-config"
apt-monitor --dry-run 2>&1 | grep -q 'linux-image-demo' && ok "--dry-run mostra o alerta"
[ ! -e /var/lib/apt-monitor/state.json ] && ok "--dry-run não grava estado" || die "dry-run gravou estado"

step "Ciclo 1: kernel + segurança, pacote em hold ignorado"
apt-monitor --once; settle
expect "2 mensagens Telegram (2 chats)" "len(d['telegram'])==2"
expect "Telegram em HTML, URL com prefixo bot, CRÍTICO" "'/bot123456789:' in d['telegram'][0]['path'] and 'CRÍTICO' in d['telegram'][0]['body']['text'] and d['telegram'][0]['body']['parse_mode']=='HTML'"
expect "demo-a/demo-sec/linux-image-demo listados, demo-held não" "all(x in d['telegram'][0]['body']['text'] for x in ('demo-a','demo-sec','linux-image-demo')) and 'demo-held' not in str(d['email'])"
expect "1 e-mail multipart (texto + HTML) com Date/Message-ID" "len(d['email'])==1 and 'text/plain' in d['email'][0] and 'text/html' in d['email'][0] and d['email'][0]['date'] and d['email'][0]['message_id']"
expect "e-mail marca o pacote de segurança" "'demo-sec (1.0 -> 2.0) [segurança]' in d['email'][0]['text/plain'] and '(1 de segurança)' in d['email'][0]['text/plain']"
expect "assunto crítico" "d['email'][0]['subject'].startswith('[') and 'Kernel' in d['email'][0]['subject']"
[ "$(stat -c %a /var/lib/apt-monitor/state.json)" = 600 ] && ok "state.json criado (600)"

step "Ciclo 2 e simulação de restart: nada novo => nenhum alerta repetido"
apt-monitor --once; apt-monitor --once; settle
expect "continua 2 Telegram + 1 e-mail" "len(d['telegram'])==2 and len(d['email'])==1"

step "Teste de envio (--test-notify)"
apt-monitor --test-notify >/dev/null; settle
expect "teste chegou nos dois canais" "len(d['telegram'])==4 and len(d['email'])==2 and 'Teste' in d['email'][1]['subject']"

step "Instala tudo => aviso de 'servidor em dia'"
apt-get install -y -qq --only-upgrade demo-a demo-sec linux-image-demo >/dev/null
apt-monitor --once; settle
expect "alerta 'em dia' enviado (hold continua ignorado)" "len(d['telegram'])==6 and 'em dia' in d['telegram'][5]['body']['text'] and 'Todas' in d['email'][2]['subject']"
apt-monitor --once; settle
expect "e não repete" "len(d['telegram'])==6"

step "Reinicialização pendente"
touch /var/run/reboot-required; echo linux-image-demo > /var/run/reboot-required.pkgs
apt-monitor --once; apt-monitor --once; settle
expect "um único alerta de reboot" "len(d['telegram'])==8 and 'Reinicialização' in d['telegram'][7]['body']['text'] and 'linux-image-demo' in d['telegram'][7]['body']['text']"
rm -f /var/run/reboot-required /var/run/reboot-required.pkgs

step "Falha de entrega: alerta é retentado, não perdido"
rm -f /var/lib/apt-monitor/state.json
sed -i 's#^API_BASE=.*#API_BASE=http://127.0.0.1:9#; /^\[Email\]/,$d' /etc/apt-monitor/apt-monitor.conf
mkpkg demo-a 3.0 /srv/upd; mkrepo /srv/upd demo-updates; apt-get update -qq >/dev/null
rc=0; apt-monitor --once >/tmp/fail.log 2>&1 || rc=$?
[ "$rc" = 1 ] && ok "exit 1 quando nenhum canal entrega" || die "rc=$rc"
grep -q 'AAEhBP0av28d' /tmp/fail.log && die "TOKEN VAZOU NO LOG" || ok "token ausente do log mesmo com erro de conexão"
[ "$(python3 -c "import json;print(json.load(open('/var/lib/apt-monitor/state.json'))['packages'])")" = "None" ] && ok "estado não marcou como notificado" || die "estado marcado indevidamente"

step "Daemon: SIGHUP recarrega, SIGTERM encerra limpo"
sed -i 's#^API_BASE=.*#API_BASE=http://127.0.0.1:8081#' /etc/apt-monitor/apt-monitor.conf
apt-monitor > /tmp/daemon.log 2>&1 & DPID=$!
sleep 4; kill -HUP $DPID; sleep 3
grep -q 'Configuração recarregada' /tmp/daemon.log && ok "SIGHUP recarregou" || { cat /tmp/daemon.log; die "sem reload"; }
kill -TERM $DPID; rc=0; wait $DPID || rc=$?
[ "$rc" = 0 ] && ok "SIGTERM => saída 0" || die "rc=$rc"

step "Remoção e purge"
kill $MOCK 2>/dev/null || true
apt-get remove -y -qq apt-monitor >/dev/null
[ -f /etc/apt-monitor/apt-monitor.conf ] && [ ! -e /usr/sbin/apt-monitor ] && ok "remove mantém conf, apaga binário"
apt-get purge -y -qq apt-monitor >/dev/null
[ ! -e /etc/apt-monitor ] && [ ! -e /var/lib/apt-monitor ] && ok "purge limpou conf e estado" || die "purge incompleto"
echo; echo "✅ $PRETTY_NAME: tudo OK"
