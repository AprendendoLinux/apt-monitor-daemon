#!/bin/bash
# Roda dentro de um container com systemd como PID 1 (ver systemd-test.sh).
set -euo pipefail
. /work/plus/tests/docker/lib.sh
. /etc/os-release; echo "=== $PRETTY_NAME | systemd $(systemctl --version | head -1 | cut -d' ' -f2) ==="
DEB=$(ls /work/plus/dist/apt-monitor-plus_*_all.deb)
CLASSIC=$(ls /work/dist/apt-monitor_*_all.deb)
CONF=/etc/apt-monitor-plus/apt-monitor.conf
STATE=/var/lib/apt-monitor-plus
SVC=apt-monitor-plus
on_exit(){ local code=$?; if [ "$code" -ne 0 ]; then echo "--- journal:"; journalctl -u apt-monitor -u $SVC --no-pager | tail -30; fi; }
trap on_exit EXIT
wait_for(){ local n=0; until eval "$1"; do sleep 1; n=$((n+1)); if [ $n -gt "${2:-30}" ]; then return 1; fi; done; return 0; }
count(){ num "len(d['telegram'])"; }

step "Repositórios locais de teste"
mkdir /etc/apt/disabled; mv /etc/apt/sources.list /etc/apt/disabled/ 2>/dev/null || true; mv /etc/apt/sources.list.d/* /etc/apt/disabled/ 2>/dev/null || true
for p in demo-a demo-sec linux-image-demo; do mkpkg $p 1.0 /srv/base; done
mkrepo /srv/base demo; apt-get update -qq >/dev/null
apt-get install -y -qq demo-a demo-sec linux-image-demo >/dev/null
mkpkg demo-sec 2.0 /srv/sec; mkrepo /srv/sec demo-security
for p in demo-a linux-image-demo; do mkpkg $p 2.0 /srv/upd; done; mkrepo /srv/upd demo-updates
apt-get update -qq >/dev/null
python3 /work/plus/tests/docker/mock_servers.py > /tmp/mock.out 2>&1 &
ok "ok"

step "APT Monitor CLÁSSICO em produção, com systemd"
apt-get install -y -qq "$CLASSIC" > /tmp/classic.log 2>&1 || { cat /tmp/classic.log; die "clássico falhou"; }
systemctl is-enabled apt-monitor >/dev/null && ok "clássico instalado e habilitado"
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
wait_for "[ \"\$(num \"len(d['telegram'])\")\" -ge 1 ]" 40 && ok "o clássico enviou o alerta" || { journalctl -u apt-monitor --no-pager | tail -20; die "clássico sem alerta"; }
expect "alerta crítico com pacote de segurança" "'CRÍTICO' in d['telegram'][0]['body']['text'] and '1 de segurança' in d['telegram'][0]['body']['text']"
N=$(count); [ "$N" = 1 ] && ok "1 alerta enviado pelo clássico"

step "Troca pelo Plus: serviço, configuração e estado migrados (systemd real)"
apt-get install -y -qq "$DEB" > /tmp/migrate.log 2>&1 || { cat /tmp/migrate.log; die "troca falhou"; }
systemctl is-active --quiet apt-monitor && die "serviço clássico continua ativo" || ok "serviço clássico parado"
systemctl list-unit-files apt-monitor.service 2>/dev/null | grep -q '^apt-monitor.service' && die "unit do clássico ficou" || ok "unit do clássico removida"
systemctl is-enabled --quiet $SVC && ok "serviço do Plus habilitado" || die "Plus não habilitado"
systemctl is-active --quiet $SVC && ok "serviço do Plus ATIVO logo após a troca (configuração migrada era válida)" || { cat /tmp/migrate.log; die "Plus inativo"; }
grep -q 'configuração do apt-monitor migrada' /tmp/migrate.log && ok "migração da configuração anunciada" || die "sem aviso"
grep -q '^BOT_TOKEN=123456789:AAEhBP0av28d' $CONF && grep -q '^\[ClientTelegram\]' $CONF && ok "conf migrado + seções do Plus" || die "conf"
PID1=$(systemctl show -p MainPID --value $SVC)
sleep 12
[ "$(count)" = "$N" ] && ok "estado migrado: o Plus NÃO repetiu o alerta já enviado pelo clássico" || die "alerta duplicado após a troca"
journalctl -u $SVC --no-pager | grep -q 'Iniciando APT Monitor Plus' && ok "banner do Plus no journal"
journalctl -u $SVC --no-pager | grep -q 'usando a lista local' && { journalctl -u $SVC --no-pager | tail; die "apt update falhou dentro do sandbox"; } || ok "'apt update' funciona dentro do sandbox (ProtectSystem=strict)"
[ "$(stat -c %a /var/log/apt-monitor-plus.log)" = 640 ] && ok "log com modo 640"
[ -f $STATE/history.db ] && [ "$(stat -c %a $STATE/history.db)" = 600 ] && ok "history.db criado dentro do sandbox (600)" || die "history.db"

step "reload (SIGHUP) roda novo ciclo; apt update dentro do serviço enxerga repositório novo"
mkpkg demo-a 3.0 /srv/upd; mkrepo /srv/upd demo-updates        # sem rodar apt-get update aqui
systemctl reload $SVC
wait_for "[ \"\$(num \"len(d['telegram'])\")\" -ge $((N+1)) ]" 40 && ok "novo alerta após reload" || { journalctl -u $SVC --no-pager | tail -20; die "sem novo alerta"; }
expect "mensagem cita demo-a" "'demo-a' in d['telegram'][$N]['body']['text']"
[ "$(systemctl show -p MainPID --value $SVC)" = "$PID1" ] && ok "mesmo PID (sem restart)" || die "PID mudou"
grep -q 'Configuração recarregada' /var/log/apt-monitor-plus.log && ok "reload registrado no log"
N=$(count)

step "ALERTA IMEDIATO: o apt muda as listas e o Plus avisa sozinho, sem reload e sem esperar o intervalo"
mkpkg demo-a 4.0 /srv/upd; mkrepo /srv/upd demo-updates
T0=$(date +%s)
apt-get update -qq >/dev/null          # (o administrador/apt-daily atualizando as listas)
wait_for "[ \"\$(num \"len(d['telegram'])\")\" -gt $N ]" 150 && ok "alerta chegou em $(( $(date +%s) - T0 ))s (CHECK_INTERVAL_HOURS=4, sem reload)" || { journalctl -u $SVC --no-pager | tail -20; die "o alerta imediato não veio"; }
expect "o alerta é da versão nova" "'demo-a' in d['telegram'][-1]['body']['text']"
grep -q 'O apt mudou as listas' /var/log/apt-monitor-plus.log && ok "log registra a detecção imediata" || die "sem log da detecção"
[ "$(systemctl show -p MainPID --value $SVC)" = "$PID1" ] && ok "mesmo PID" || die "PID mudou"
sleep 5; N=$(count)
sleep 65; [ "$(count)" = "$N" ] && ok "o próprio apt update do Plus não gera laço de alertas" || die "laço de checagens"

step "logrotate não reinicia o serviço nem repete alertas"
logrotate -f /etc/logrotate.d/apt-monitor-plus
[ "$(systemctl show -p MainPID --value $SVC)" = "$PID1" ] && ok "PID inalterado após logrotate" || die "serviço reiniciou"
systemctl reload $SVC; sleep 8
[ -s /var/log/apt-monitor-plus.log ] && grep -q 'Configuração recarregada' /var/log/apt-monitor-plus.log && ok "daemon continua gravando no arquivo novo (WatchedFileHandler)" || die "log vazio após rotação"
[ "$(count)" = "$N" ] && ok "nenhum alerta duplicado" || die "alerta duplicado"

step "RELATÓRIO AO CLIENTE: o administrador atualiza e o próprio daemon envia no horário"
RT=$(date -u -d '+2 minutes' +%H:%M)
cat >> $CONF <<EOC

[Report]
ADMIN_NAME=Henrique Fagundes
REPORT_TIME=$RT
REPORT_TIMEZONE=UTC

[ClientTelegram]
BOT_TOKEN=987654321:AAFclientEXAMPLEexampleTOKEN_abcd1234
CHAT_IDS=999
API_BASE=http://127.0.0.1:8081

[ClientEmail]
SMTP_SERVER=127.0.0.1
SMTP_PORT=2525
SMTP_SECURITY=none
SENDER_NAME=Suporte Técnico
SENDER_EMAIL=suporte@example.com
RECIPIENT_EMAILS=cliente@example.com
EOC
systemctl reload $SVC; sleep 4
grep -q "às $RT (UTC)" /var/log/apt-monitor-plus.log && ok "relatório agendado para $RT UTC" || die "agendamento não registrado"
apt-get install -y -qq --only-upgrade demo-sec >/dev/null          # o administrador trabalha
ok "demo-sec atualizado (2 minutos para o horário do relatório)"
wait_for "[ \"\$(num \"sum(1 for m in d['telegram'] if m['body']['chat_id']=='999')\")\" -ge 1 ]" 260 && ok "o cliente recebeu o relatório no Telegram, enviado pelo daemon" || { journalctl -u $SVC --no-pager | tail -25; die "relatório não saiu"; }
expect "texto: administrador, 1 vez, 1 pacote, sucesso" "any(m['body']['chat_id']=='999' and 'O administrador Henrique Fagundes atualizou o servidor 1 vez' in m['body']['text'] and 'Com sucesso: <b>1</b>' in m['body']['text'] and 'Com falha: <b>0</b>' in m['body']['text'] for m in d['telegram'])"
wait_for "[ \"\$(num \"sum(1 for e in d['email'] if e['to']=='cliente@example.com')\")\" -ge 1 ]" 30 && ok "e o cliente também recebeu por e-mail" || die "sem e-mail do cliente"
expect "e-mail do cliente: remetente próprio e tabela de pacotes" "any(e['to']=='cliente@example.com' and 'Suporte Técnico' in e['from'] and 'demo-sec' in e['text/html'] and 'Relatório diário' in e['subject'] for e in d['email'])"
expect "o administrador NÃO recebeu relatório" "all('Relatório diário' not in m['body']['text'] for m in d['telegram'] if m['body']['chat_id']=='111') and all(e['to']!='ops@example.com' or 'Relatório diário' not in e['subject'] for e in d['email'])"
NR=$(num "len(d['telegram'])"); ER=$(num "len(d['email'])")
sleep 75
[ "$(num "len(d['telegram'])")" = "$NR" ] && [ "$(num "len(d['email'])")" = "$ER" ] && ok "continua um relatório só no dia (nada repetido nos ciclos seguintes)" || die "relatório repetido"

step "Persistência entre restarts (alertas e relatório)"
N=$(count); E=$(num "len(d['email'])")
systemctl restart $SVC; sleep 12
[ "$(count)" = "$N" ] && [ "$(num "len(d['email'])")" = "$E" ] && ok "restart do serviço não reenvia alerta nem relatório" || die "reenviou após restart"

step "Parada rápida"
S=$(date +%s); systemctl stop $SVC; E=$(date +%s)
[ $((E-S)) -le 5 ] && ok "stop em $((E-S))s" || die "stop demorou"
[ "$(systemctl show -p Result --value $SVC)" = success ] && ok "Result=success" || die "Result != success"

step "Configuração inválida => falha com 78 e SEM loop de restart"
sed -i 's/^BOT_TOKEN=.*/BOT_TOKEN=seu_bot_token_aqui/; /^\[Email\]/,$d' $CONF
systemctl start $SVC || true
sleep 40
[ "$(systemctl show -p ExecMainStatus --value $SVC)" = 78 ] && ok "ExecMainStatus=78" || die "status $(systemctl show -p ExecMainStatus --value $SVC)"
[ "$(systemctl show -p NRestarts --value $SVC)" = 0 ] && ok "NRestarts=0 (RestartPreventExitStatus)" || die "reiniciou em loop"
systemctl is-failed --quiet $SVC && ok "serviço em 'failed' com mensagem clara:" && journalctl -u $SVC --no-pager | tail -2

step "Exposição de segurança do unit (informativo)"
systemd-analyze security $SVC.service --no-pager 2>/dev/null | tail -1 || true

step "Limpeza do clássico residual não toca no Plus; remoção e purge do Plus"
dpkg -l apt-monitor 2>/dev/null | grep -q '^rc' && ok "clássico está 'removido, com configuração' (rc)" || die "estado do clássico: $(dpkg -l apt-monitor 2>&1 | tail -1)"
apt-get purge -y -qq apt-monitor >/dev/null 2>&1
[ ! -e /etc/apt-monitor ] && [ ! -e /var/lib/apt-monitor ] && ok "purge do clássico limpou só os caminhos dele" || die "purge do clássico incompleto"
[ -f $CONF ] && [ -f $STATE/history.db ] && [ -f $STATE/state.json ] && ok "conf, histórico e estado do Plus intactos" || die "o purge do clássico atingiu o Plus"
apt-get remove -y -qq apt-monitor-plus >/dev/null
systemctl list-unit-files $SVC.service 2>/dev/null | grep -q $SVC && die "unit ficou" || ok "unit removida"
apt-get purge -y -qq apt-monitor-plus >/dev/null
[ ! -e $STATE ] && [ ! -e /var/log/apt-monitor-plus.log ] && [ ! -e /etc/apt-monitor-plus ] && ok "purge limpou tudo do Plus" || die "purge incompleto"
echo; echo "✅ $PRETTY_NAME (systemd): tudo OK"
