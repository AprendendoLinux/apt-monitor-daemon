#!/bin/bash
# Roda DENTRO do container (Debian/Ubuntu). /work = raiz do repositório, com os .deb já construídos:
#   /work/dist/apt-monitor_*_all.deb            (clássico)
#   /work/plus/dist/apt-monitor-plus_*_all.deb  (Plus)
set -euo pipefail
. /work/plus/tests/docker/lib.sh
. /etc/os-release; echo "=== $PRETTY_NAME | $(python3 --version 2>&1) ==="
DEB=$(ls /work/plus/dist/apt-monitor-plus_*_all.deb)
CLASSIC=$(ls /work/dist/apt-monitor_*_all.deb)
CONF=/etc/apt-monitor-plus/apt-monitor.conf
STATE=/var/lib/apt-monitor-plus

step "Dependências e repositórios locais de teste"
if [ "${VERSION_CODENAME:-}" = bullseye ]; then   # Debian 11 já saiu dos mirrors padrão
  printf 'deb http://archive.debian.org/debian bullseye main\ndeb http://archive.debian.org/debian-security bullseye-security main\n' > /etc/apt/sources.list
  echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99archive
  rm -f /etc/apt/sources.list.d/*
fi
apt-get update -qq >/dev/null
apt-get install -y -qq python3-apt apt-utils iproute2 ca-certificates dpkg-dev python3-requests tzdata >/dev/null
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

step "Migração: instala o APT Monitor CLÁSSICO e troca pelo Plus"
apt-get install -y -qq "$CLASSIC" >/dev/null
[ -f /usr/lib/apt-monitor/apt_monitor.py ] || die "clássico não instalou"
sed -i 's/^CHECK_INTERVAL_HOURS=.*/CHECK_INTERVAL_HOURS=1/; s/^BOT_TOKEN=.*/BOT_TOKEN=111111111:AAEclassicEXAMPLEexampleTOKEN_abcd1/' /etc/apt-monitor/apt-monitor.conf   # conf "personalizado"
echo '{"packages": ["demo-a=2.0"], "last_notified": 1700000000.0, "reboot_notified": false}' > /var/lib/apt-monitor/state.json
apt-get install -y -qq "$DEB" > /tmp/migrate.log 2>&1 || { cat /tmp/migrate.log; die "instalação do Plus falhou"; }
[ ! -e /usr/lib/apt-monitor/apt_monitor.py ] && ok "o apt removeu o clássico (Conflicts)" || die "clássico continua instalado"
dpkg -s apt-monitor 2>/dev/null | grep -q '^Status: .* installed' && die "clássico ainda 'installed'" || ok "pacote apt-monitor não está mais instalado"
grep -q 'configuração do apt-monitor migrada' /tmp/migrate.log && ok "mensagem de migração da configuração" || { cat /tmp/migrate.log; die "sem aviso de migração"; }
grep -q '^CHECK_INTERVAL_HOURS=1' $CONF && grep -q 'AAEclassicEXAMPLE' $CONF && ok "configuração do clássico foi copiada para o Plus" || die "conf não migrado"
grep -q '^# >>> APT Monitor Plus >>>' $CONF && grep -q '^\[ClientTelegram\]' $CONF && grep -q '^#PENDING_ALERT_DAYS=3' $CONF && ok "seções novas do Plus acrescentadas (comentadas)" || die "faltam as seções do Plus"
[ "$(grep -c '^\[Telegram\]' $CONF)" = 1 ] && ok "sem seções duplicadas" || die "[Telegram] duplicado"
[ "$(stat -c %a $CONF)" = 600 ] && ok "conf migrado com modo 600" || die "modo do conf"
python3 -c "import json;assert json.load(open('$STATE/state.json'))['packages']==['demo-a=2.0']" && [ "$(stat -c %a $STATE/state.json)" = 600 ] && ok "state.json migrado (alertas já enviados não se repetem)" || die "estado não migrado"
[ -f /etc/apt-monitor/apt-monitor.conf ] && ok "conf do clássico permanece (para voltar atrás)" || die "conf do clássico sumiu"
apt-monitor-plus --version | grep -q '^apt-monitor-plus 1\.' && apt-monitor --version | grep -q '^apt-monitor-plus ' && ok "comando apt-monitor-plus e atalho apt-monitor" || die "comandos"
[ -f /usr/lib/systemd/system/apt-monitor-plus.service ] && [ ! -e /usr/lib/systemd/system/apt-monitor.service ] && ok "unit do Plus instalada, a do clássico removida" || die "units"
apt-get purge -y -qq apt-monitor >/dev/null 2>&1
[ ! -e /etc/apt-monitor ] && [ ! -e /var/lib/apt-monitor ] && ok "purge do clássico residual limpou os caminhos DELE" || die "purge do clássico incompleto"
[ -f $CONF ] && [ -f $STATE/state.json ] && ok "...sem tocar nos arquivos do Plus" || die "o purge do clássico apagou arquivos do Plus"

step "Arquivos instalados"
[ "$(stat -c %a $STATE)" = 750 ] && ok "$STATE 750" || die "modo do state dir"
# Imagens mínimas (ex.: Ubuntu) excluem /usr/share/doc e /usr/share/man via dpkg; em servidores normais eles existem.
if grep -rqs 'path-exclude=/usr/share/doc' /etc/dpkg/dpkg.cfg.d/ /etc/dpkg/dpkg.cfg; then
  ok "(imagem mínima exclui /usr/share/doc: verificação da documentação instalada ignorada)"
else
  [ -f /usr/share/doc/apt-monitor-plus/examples/apt-monitor.conf ] && [ -f /usr/share/doc/apt-monitor-plus/docs/configuracao.md ] && ok "exemplo de conf e documentação em /usr/share/doc" || die "sem doc"
fi
if grep -rqs 'path-exclude=/usr/share/man' /etc/dpkg/dpkg.cfg.d/ /etc/dpkg/dpkg.cfg; then
  ok "(imagem mínima exclui /usr/share/man: verificação da man page ignorada)"
else
  [ -f /usr/share/man/man8/apt-monitor-plus.8.gz ] && ok "man page" || die "sem man"
fi
LIST=$(dpkg-deb -c "$DEB")      # (em variável: grep -q em pipeline + pipefail daria SIGPIPE)
grep -q './usr/share/man/man8/apt-monitor-plus.8.gz' <<<"$LIST" && grep -q './usr/share/doc/apt-monitor-plus/docs/configuracao.md' <<<"$LIST" && grep -q './usr/share/doc/apt-monitor-plus/examples/apt-monitor.conf' <<<"$LIST" && ok "o .deb contém man page, documentação e conf de exemplo" || die "faltam arquivos no .deb"

step "Configuração de exemplo (placeholders) é rejeitada com EX_CONFIG"
cat > /tmp/placeholder.conf <<'EOC'
[Telegram]
BOT_TOKEN=seu_bot_token_aqui
CHAT_IDS=12345678, 87654321
[Email]
SMTP_SERVER=smtp.seuservidor.com
RECIPIENT_EMAILS=admin@seuservidor.com
EOC
rc=0; apt-monitor-plus -c /tmp/placeholder.conf --check-config >/dev/null 2>&1 || rc=$?
[ "$rc" = 78 ] && ok "exit 78" || die "esperava 78, veio $rc"
dpkg-deb --fsys-tarfile "$DEB" | tar -xO ./usr/share/doc/apt-monitor-plus/examples/apt-monitor.conf > /tmp/example.conf     # direto do .deb
rc=0; apt-monitor-plus -c /tmp/example.conf --check-config >/dev/null 2>&1 || rc=$?
[ "$rc" = 78 ] && ok "o conf de exemplo instalado também é rejeitado (nada é enviado até configurar)" || die "exemplo: $rc"
sed -i 's/^BOT_TOKEN=.*/BOT_TOKEN=123456789:AAEhBP0av28dEXAMPLEexampleTOKEN_xyz12/; s/^CHAT_IDS=.*/CHAT_IDS=1/' /tmp/example.conf
OUT=$(apt-monitor-plus -c /tmp/example.conf --check-config 2>&1)
grep -qi 'cliente não configurado' <<<"$OUT" && die "seções do cliente vazias geraram aviso: $OUT" || ok "seções do cliente vazias (tudo comentado) não geram aviso"
grep -q 'Relatório ao cliente: desativado' <<<"$OUT" && ok "--check-config: cliente desativado" || die "check-config do cliente: $OUT"

step "Configuração real apontando para Telegram/SMTP falsos"
python3 /work/plus/tests/docker/mock_servers.py & MOCK=$!
cat > $CONF <<'EOC'
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
rm -f $STATE/state.json
sleep 1
apt-monitor-plus --check-config >/dev/null && ok "--check-config"
apt-monitor-plus --dry-run 2>&1 | grep -q 'linux-image-demo' && ok "--dry-run mostra o alerta"
[ ! -e $STATE/state.json ] && ok "--dry-run não grava estado" || die "dry-run gravou estado"

step "Ciclo 1: kernel + segurança, pacote em hold ignorado"
apt-monitor-plus --once; settle
expect "2 mensagens Telegram (2 chats)" "len(d['telegram'])==2"
expect "Telegram em HTML, URL com prefixo bot, CRÍTICO" "'/bot123456789:' in d['telegram'][0]['path'] and 'CRÍTICO' in d['telegram'][0]['body']['text'] and d['telegram'][0]['body']['parse_mode']=='HTML'"
expect "demo-a/demo-sec/linux-image-demo listados, demo-held não" "all(x in d['telegram'][0]['body']['text'] for x in ('demo-a','demo-sec','linux-image-demo')) and 'demo-held' not in str(d['email'])"
expect "1 e-mail multipart (texto + HTML) com Date/Message-ID" "len(d['email'])==1 and 'text/plain' in d['email'][0] and 'text/html' in d['email'][0] and d['email'][0]['date'] and d['email'][0]['message_id']"
expect "e-mail marca o pacote de segurança" "'demo-sec (1.0 -> 2.0) [segurança]' in d['email'][0]['text/plain'] and '(1 de segurança)' in d['email'][0]['text/plain']"
expect "assunto crítico" "d['email'][0]['subject'].startswith('[') and 'Kernel' in d['email'][0]['subject']"
expect "e-mail novo do Plus: cartões, selos, comando e marca" "all(x in d['email'][0]['text/html'] for x in ('CRÍTICO','Kernel','sudo apt update','APT&nbsp;MONITOR&nbsp;<span','Detectado em'))"
expect "e-mail sem imagens/recursos externos" "'<img' not in d['email'][0]['text/html'] and 'http://' not in d['email'][0]['text/html'].replace('http://www.w3.org','')"
[ "$(stat -c %a $STATE/state.json)" = 600 ] && ok "state.json criado (600)"

step "Ciclo 2 e simulação de restart: nada novo => nenhum alerta repetido"
apt-monitor-plus --once; apt-monitor-plus --once; settle
expect "continua 2 Telegram + 1 e-mail" "len(d['telegram'])==2 and len(d['email'])==1"

step "Teste de envio (--test-notify)"
apt-monitor-plus --test-notify >/dev/null; settle
expect "teste chegou nos dois canais" "len(d['telegram'])==4 and len(d['email'])==2 and 'Teste' in d['email'][1]['subject']"

step "Instala tudo => aviso de 'servidor em dia'"
apt-get install -y -qq --only-upgrade demo-a demo-sec linux-image-demo >/dev/null
apt-monitor-plus --once; settle
expect "alerta 'em dia' enviado (hold continua ignorado)" "len(d['telegram'])==6 and 'em dia' in d['telegram'][5]['body']['text'] and 'Todas' in d['email'][2]['subject']"
apt-monitor-plus --once; settle
expect "e não repete" "len(d['telegram'])==6"

step "Reinicialização pendente"
touch /var/run/reboot-required; echo linux-image-demo > /var/run/reboot-required.pkgs
apt-monitor-plus --once; apt-monitor-plus --once; settle
expect "um único alerta de reboot" "len(d['telegram'])==8 and 'Reinicialização' in d['telegram'][7]['body']['text'] and 'linux-image-demo' in d['telegram'][7]['body']['text']"
rm -f /var/run/reboot-required /var/run/reboot-required.pkgs

step "Falha de entrega: alerta é retentado, não perdido"
rm -f $STATE/state.json
sed -i 's#^API_BASE=.*#API_BASE=http://127.0.0.1:9#; /^\[Email\]/,$d' $CONF
mkpkg demo-a 3.0 /srv/upd; mkrepo /srv/upd demo-updates; apt-get update -qq >/dev/null
rc=0; apt-monitor-plus --once >/tmp/fail.log 2>&1 || rc=$?
[ "$rc" = 1 ] && ok "exit 1 quando nenhum canal entrega" || die "rc=$rc"
grep -q 'AAEhBP0av28d' /tmp/fail.log && die "TOKEN VAZOU NO LOG" || ok "token ausente do log mesmo com erro de conexão"
[ "$(python3 -c "import json;print(json.load(open('$STATE/state.json'))['packages'])")" = "None" ] && ok "estado não marcou como notificado" || die "estado marcado indevidamente"

step "Daemon: SIGHUP recarrega, SIGTERM encerra limpo; cria o banco de histórico"
sed -i 's#^API_BASE=.*#API_BASE=http://127.0.0.1:8081#' $CONF
apt-monitor-plus > /tmp/daemon.log 2>&1 & DPID=$!
sleep 4; kill -HUP $DPID; sleep 3
grep -q 'Configuração recarregada' /tmp/daemon.log && ok "SIGHUP recarregou" || { cat /tmp/daemon.log; die "sem reload"; }
grep -q 'Iniciando APT Monitor Plus' /tmp/daemon.log && ok "banner do Plus no log" || die "sem banner"
[ -f $STATE/history.db ] && [ "$(stat -c %a $STATE/history.db)" = 600 ] && ok "history.db criado (600)" || die "sem history.db"
kill -TERM $DPID; rc=0; wait $DPID || rc=$?
[ "$rc" = 0 ] && ok "SIGTERM => saída 0" || die "rc=$rc"

step "Cliente: configuração, teste de envio e prévia"
N0=$(num "len(d['telegram'])"); E0=$(num "len(d['email'])")
cat >> $CONF <<'EOC'

[Report]
ADMIN_NAME=Henrique Fagundes
REPORT_TIME=22:30
REPORT_TIMEZONE=America/Sao_Paulo

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
OUT=$(apt-monitor-plus --check-config 2>&1)
grep -q 'Relatório ao cliente: telegram, email' <<<"$OUT" && ok "--check-config lista os canais do cliente" || die "check-config: $OUT"
apt-monitor-plus --test-notify >/dev/null; settle
expect "teste do admin foi para os 2 chats do admin" "sum(1 for m in d['telegram'][$N0:] if m['body']['chat_id'] in ('111','222') and 'Teste' in m['body']['text'])==2"
expect "teste do cliente: relatório de exemplo, outro bot, outro chat" "any(m['body']['chat_id']=='999' and '/bot987654321:' in m['path'] and 'Teste do relatório diário' in m['body']['text'] for m in d['telegram'][$N0:])"
expect "teste do cliente por e-mail, só para o cliente" "any(e['to']=='cliente@example.com' and 'TESTE' in e['subject'] and 'Mensagem de teste' in e['text/html'] for e in d['email'][$E0:])"
expect "o cliente NUNCA recebe o alerta do admin" "all('CRÍTICO' not in m['body']['text'] and 'Alerta' not in m['body']['text'] for m in d['telegram'][$N0:] if m['body']['chat_id']=='999')"
expect "e-mail do cliente sem IPs" "all('IPs' not in e['text/plain'] for e in d['email'][$E0:] if e['to']=='cliente@example.com')"
OUT=$(apt-monitor-plus --report --dry-run 2>&1)
grep -q 'Relatório diário\|Nenhuma atualização' <<<"$OUT" && ok "--report --dry-run pré-visualiza" || die "dry-run do relatório: $OUT"

step "Relatório real: o administrador atualiza e o cliente recebe"
sleep 2     # o banco só registra o que acontece DEPOIS de criado
apt-get install -y -qq --only-upgrade demo-a >/dev/null
N1=$(num "len(d['telegram'])"); E1=$(num "len(d['email'])")
apt-monitor-plus --report; settle
expect "Telegram ao cliente: administrador, 1 atualização, 1 pacote com sucesso" "any(m['body']['chat_id']=='999' and 'O administrador Henrique Fagundes atualizou o servidor 1 vez' in m['body']['text'] and 'Pacotes atualizados: <b>1</b>' in m['body']['text'] and 'Com sucesso: <b>1</b>' in m['body']['text'] and 'Com falha: <b>0</b>' in m['body']['text'] for m in d['telegram'][$N1:])"
expect "e-mail ao cliente com tabela de pacotes e remetente próprio" "any(e['to']=='cliente@example.com' and 'Relatório diário' in e['subject'] and 'demo-a' in e['text/html'] and 'Suporte Técnico' in e['from'] and 'suporte@example.com' in e['from'] for e in d['email'][$E1:])"
expect "nada foi para os chats dos administradores" "all(m['body']['chat_id']=='999' for m in d['telegram'][$N1:])"
N2=$(num "len(d['telegram'])")
apt-monitor-plus --report >/tmp/again.log 2>&1; settle
[ "$(num "len(d['telegram'])")" = "$N2" ] && grep -q 'Não há atualizações novas' /tmp/again.log && ok "sem novidade, nada é reenviado" || { cat /tmp/again.log; die "reenviou"; }

step "Pendência antiga (mais de 3 dias): relatório de pendências, sem citar nomes"
python3 -c "
import sqlite3, time
db = sqlite3.connect('$STATE/history.db')
db.execute(\"insert or replace into pending values ('demo-antigo','1.0','2.0',1,?)\", (int(time.time()) - 5*86400,))
db.execute(\"insert or replace into pending values ('demo-recente','1.0','2.0',0,?)\", (int(time.time()) - 86400,))
db.commit()"
N3=$(num "len(d['telegram'])"); E3=$(num "len(d['email'])")
apt-monitor-plus --report; settle
expect "Telegram: pendências com idade e a sugestão" "any(m['body']['chat_id']=='999' and 'Atualizações pendentes' in m['body']['text'] and 'demo-antigo — 5 dias' in m['body']['text'] and 'demo-recente' in m['body']['text'] and 'Sugerimos entrar em contato com o administrador do servidor' in m['body']['text'] for m in d['telegram'][$N3:])"
expect "NENHUM nome do administrador no relatório de pendências" "all('Henrique' not in m['body']['text'] for m in d['telegram'][$N3:]) and all('Henrique' not in str(e) for e in d['email'][$E3:])"
expect "e-mail: assunto de atenção e tabela 'Aguardando'" "any('Atenção: atualizações pendentes' in e['subject'] and 'Aguardando' in e['text/html'] and '5 dias' in e['text/html'] for e in d['email'][$E3:])"
python3 -c "
import sqlite3
db = sqlite3.connect('$STATE/history.db'); db.execute('delete from pending'); db.commit()"
N4=$(num "len(d['telegram'])")
apt-monitor-plus --report >/tmp/again2.log 2>&1; settle
[ "$(num "len(d['telegram'])")" = "$N4" ] && ok "sem pendência e sem novidade, nada é enviado" || die "enviou sem motivo"

step "Remoção e purge"
kill $MOCK 2>/dev/null || true
apt-get remove -y -qq apt-monitor-plus >/dev/null
[ -f $CONF ] && [ ! -e /usr/sbin/apt-monitor-plus ] && [ ! -e /usr/sbin/apt-monitor ] && ok "remove mantém conf, apaga binários" || die "remove"
[ -f $STATE/history.db ] && ok "remove mantém o histórico" || die "histórico apagado no remove"
apt-get purge -y -qq apt-monitor-plus >/dev/null
[ ! -e /etc/apt-monitor-plus ] && [ ! -e $STATE ] && ok "purge limpou conf, estado e histórico" || die "purge incompleto"
step "Rollback e reinstalação do Plus: o bloco do Plus não duplica"
mkdir -p /etc/apt-monitor
printf '%s\n' '[Telegram]' 'BOT_TOKEN=111111111:AAEclassicEXAMPLEexampleTOKEN_abcd1' 'CHAT_IDS=111' > /etc/apt-monitor/apt-monitor.conf
printf '\n# >>> APT Monitor Plus >>> (deixado por uma instalação anterior do Plus)\n#[Report]\n' >> /etc/apt-monitor/apt-monitor.conf
dpkg -s apt-monitor >/dev/null 2>&1 && die "clássico não deveria estar instalado"
apt-get install -y -qq "$DEB" >/dev/null 2>&1 || die "reinstalação do Plus falhou"
[ "$(grep -c '^# >>> APT Monitor Plus >>>' $CONF)" = 1 ] && ok "marcador do Plus aparece uma única vez" || die "bloco do Plus duplicado"
grep -q 'AAEclassicEXAMPLE' $CONF && ok "configuração do clássico copiada" || die "conf não migrado"
rm -rf /etc/apt-monitor
apt-get purge -y -qq apt-monitor-plus >/dev/null 2>&1

echo; echo "✅ $PRETTY_NAME: tudo OK"
