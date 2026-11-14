#!/bin/bash
# Roda dentro de um container com systemd como PID 1 (ver systemd-test.sh).
set -euo pipefail
. /work/tests/docker/lib.sh
. /etc/os-release; echo "=== $PRETTY_NAME | systemd $(systemctl --version | head -1 | cut -d' ' -f2) ==="
DEB=$(ls /work/dist/apt-monitor_*_all.deb)
on_exit(){ local code=$?; if [ "$code" -ne 0 ]; then echo "--- journal:"; journalctl -u apt-monitor --no-pager | tail -25; fi; }
trap on_exit EXIT
wait_for(){ local n=0; until eval "$1"; do sleep 1; n=$((n+1)); if [ $n -gt "${2:-30}" ]; then return 1; fi; done; return 0; }

step "Repositórios locais de teste"
mkdir /etc/apt/disabled; mv /etc/apt/sources.list /etc/apt/disabled/ 2>/dev/null || true; mv /etc/apt/sources.list.d/* /etc/apt/disabled/ 2>/dev/null || true
for p in demo-a demo-sec linux-image-demo; do mkpkg $p 1.0 /srv/base; done
mkrepo /srv/base demo; apt-get update -qq >/dev/null
apt-get install -y -qq demo-a demo-sec linux-image-demo >/dev/null
mkpkg demo-sec 2.0 /srv/sec; mkrepo /srv/sec demo-security
for p in demo-a linux-image-demo; do mkpkg $p 2.0 /srv/upd; done; mkrepo /srv/upd demo-updates
apt-get update -qq >/dev/null
python3 /work/tests/docker/mock_servers.py > /tmp/mock.out 2>&1 &
ok "ok"

step "Upgrade 1.0 -> nova com systemd de verdade"
apt-get install -y -qq /work/tests/docker/apt-monitor_1.0-1_all.deb >/dev/null 2>&1 || true
systemctl is-enabled apt-monitor >/dev/null 2>&1 && ok "1.0 instalada e habilitada"
apt-get install -y -qq -o Dpkg::Options::=--force-confnew "$DEB" > /tmp/upgrade.log 2>&1 || { cat /tmp/upgrade.log; die "upgrade falhou"; }
systemctl is-enabled apt-monitor >/dev/null && ok "serviço habilitado após upgrade (o prerm da 1.0 o desabilitava)" || die "não habilitado"
systemctl is-active --quiet apt-monitor && die "iniciou com config de exemplo" || ok "NÃO iniciou com a config de exemplo"
grep -q 'NÃO foi iniciado' /tmp/upgrade.log && ok "mensagem orientando o administrador" || { cat /tmp/upgrade.log; die "sem aviso no postinst"; }
[ ! -e /opt/apt-monitor ] && ok "/opt/apt-monitor removido" || die "/opt antigo"

step "Configura e inicia (hardening ativo)"
cat > /etc/apt-monitor/apt-monitor.conf <<'EOC'
[Telegram]
BOT_TOKEN=123456789:AAEhBP0av28dEXAMPLEexampleTOKEN_xyz12
CHAT_IDS=111
API_BASE=http://127.0.0.1:8081
[Monitor]
CHECK_INTERVAL_HOURS=4
UPDATE_CACHE=true
[Email]
SMTP_SERVER=127.0.0.1
SMTP_PORT=2525
SMTP_SECURITY=none
RECIPIENT_EMAILS=ops@example.com
SENDER_EMAIL=monitor@example.com
EOC
sleep 1
systemctl restart apt-monitor
wait_for "[ \"\$(mock \"len(d['telegram'])>=1\")\" = True ]" 40 && ok "primeiro alerta enviado pelo serviço" || { journalctl -u apt-monitor --no-pager | tail -30; die "sem alerta"; }
expect "alerta crítico com pacote de segurança" "'CRÍTICO' in d['telegram'][0]['body']['text'] and '1 de segurança' in d['telegram'][0]['body']['text']"
expect "IPs detectados dentro do sandbox (ip addr / AF_NETLINK)" "'IPs:</b> 172.' in d['telegram'][0]['body']['text']"
systemctl is-active --quiet apt-monitor && ok "serviço ativo" || die "inativo"
PID1=$(systemctl show -p MainPID --value apt-monitor)
journalctl -u apt-monitor --no-pager | grep -q 'usando a lista local' && { journalctl -u apt-monitor --no-pager | tail; die "apt update falhou dentro do sandbox"; } || ok "'apt update' funciona dentro do sandbox (ProtectSystem=strict)"
[ "$(stat -c %a /var/log/apt-monitor.log)" = 640 ] && ok "log com modo 640"

step "reload (SIGHUP) roda novo ciclo; apt update dentro do serviço enxerga repositório novo"
mkpkg demo-a 3.0 /srv/upd; mkrepo /srv/upd demo-updates        # sem rodar apt-get update aqui
systemctl reload apt-monitor
wait_for "[ \"\$(mock \"len(d['telegram'])>=2\")\" = True ]" 40 && ok "novo alerta após reload" || { journalctl -u apt-monitor --no-pager | tail -20; die "sem 2º alerta"; }
expect "mensagem cita demo-a" "'demo-a' in d['telegram'][1]['body']['text']"
[ "$(systemctl show -p MainPID --value apt-monitor)" = "$PID1" ] && ok "mesmo PID (sem restart)" || die "PID mudou"
grep -q 'Configuração recarregada' /var/log/apt-monitor.log && ok "reload registrado no log"

step "logrotate não reinicia o serviço nem repete alertas"
N=$(mock "len(d['telegram'])")
logrotate -f /etc/logrotate.d/apt-monitor
[ "$(systemctl show -p MainPID --value apt-monitor)" = "$PID1" ] && ok "PID inalterado após logrotate" || die "serviço reiniciou"
systemctl reload apt-monitor; sleep 8
[ -s /var/log/apt-monitor.log ] && grep -q 'Configuração recarregada' /var/log/apt-monitor.log && ok "daemon continua gravando no arquivo novo (WatchedFileHandler)" || die "log vazio após rotação"
[ "$(mock "len(d['telegram'])")" = "$N" ] && ok "nenhum alerta duplicado" || die "alerta duplicado"

step "Persistência do estado entre restarts"
systemctl restart apt-monitor; sleep 8
[ "$(mock "len(d['telegram'])")" = "$N" ] && ok "restart do serviço não reenvia alerta" || die "reenviou após restart"

step "Parada rápida"
S=$(date +%s); systemctl stop apt-monitor; E=$(date +%s)
[ $((E-S)) -le 5 ] && ok "stop em $((E-S))s" || die "stop demorou"
[ "$(systemctl show -p Result --value apt-monitor)" = success ] && ok "Result=success" || die "Result != success"

step "Configuração inválida => falha com 78 e SEM loop de restart"
sed -i 's/^BOT_TOKEN=.*/BOT_TOKEN=seu_bot_token_aqui/; /^\[Email\]/,$d' /etc/apt-monitor/apt-monitor.conf
systemctl start apt-monitor || true
sleep 40
[ "$(systemctl show -p ExecMainStatus --value apt-monitor)" = 78 ] && ok "ExecMainStatus=78" || die "status $(systemctl show -p ExecMainStatus --value apt-monitor)"
[ "$(systemctl show -p NRestarts --value apt-monitor)" = 0 ] && ok "NRestarts=0 (RestartPreventExitStatus)" || die "reiniciou em loop"
systemctl is-failed --quiet apt-monitor && ok "serviço em 'failed' com mensagem clara:" && journalctl -u apt-monitor --no-pager | tail -2

step "Exposição de segurança do unit (informativo)"
systemd-analyze security apt-monitor.service --no-pager 2>/dev/null | tail -1 || true

step "Remoção e purge"
apt-get remove -y -qq apt-monitor >/dev/null
systemctl list-unit-files apt-monitor.service 2>/dev/null | grep -q apt-monitor && die "unit ficou" || ok "unit removida"
apt-get purge -y -qq apt-monitor >/dev/null
[ ! -e /var/lib/apt-monitor ] && [ ! -e /var/log/apt-monitor.log ] && ok "purge limpou" || die "purge incompleto"
echo; echo "✅ $PRETTY_NAME (systemd): tudo OK"
