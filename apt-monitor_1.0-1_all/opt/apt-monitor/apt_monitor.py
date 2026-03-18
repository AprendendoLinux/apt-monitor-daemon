import apt
import requests
import time
import socket
import subprocess
import configparser
import os
import sys
import smtplib
import logging
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

CONFIG_FILE = "/etc/apt-monitor/apt-monitor.conf"
LOG_FILE = "/var/log/apt-monitor.log"

# Configuração Avançada de Logging (Arquivo + Console)
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
# Adiciona o log na saída padrão para o systemd/journalctl capturar também
console = logging.StreamHandler()
console.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')
console.setFormatter(formatter)
logging.getLogger('').addHandler(console)

def load_config():
    config = configparser.ConfigParser()
    if not os.path.exists(CONFIG_FILE):
        logging.error(f"Arquivo de configuração {CONFIG_FILE} não encontrado.")
        sys.exit(1)
    
    config.read(CONFIG_FILE)
    
    try:
        bot_token = config.get("Telegram", "BOT_TOKEN")
        chat_ids = [cid.strip() for cid in config.get("Telegram", "CHAT_IDS").split(",") if cid.strip()]
        horas_rotacao = config.getfloat("Monitor", "CHECK_INTERVAL_HOURS", fallback=4.0)
    except (configparser.NoOptionError, configparser.NoSectionError) as e:
        logging.error(f"Erro na estrutura base do conf: {e}")
        sys.exit(1)
        
    email_config = None
    if config.has_section("Email"):
        try:
            email_config = {
                "server": config.get("Email", "SMTP_SERVER"),
                "port": config.getint("Email", "SMTP_PORT"),
                "user": config.get("Email", "SMTP_USER"),
                "pass": config.get("Email", "SMTP_PASS"),
                "sender": config.get("Email", "SENDER_EMAIL"),
                "recipients": [e.strip() for e in config.get("Email", "RECIPIENT_EMAILS").split(",") if e.strip()]
            }
        except Exception as e:
            logging.warning(f"Configuração de e-mail incompleta ou ausente. O envio será ignorado. Detalhe: {e}")

    return bot_token, chat_ids, horas_rotacao, email_config

def get_machine_ips():
    try:
        output = subprocess.check_output(['hostname', '-I'], text=True).strip()
        ips = output.split()
        return ", ".join(ips) if ips else "Nenhum IP detectado"
    except Exception as e:
        logging.error(f"Erro ao obter IPs da máquina: {e}")
        return "Erro ao obter IPs"

def get_upgradable_packages():
    cache = apt.Cache()
    try:
        cache.update()
        cache.open(None)
    except Exception as e:
        logging.error(f"Erro ao atualizar o cache do APT: {e}")
        return []
    return [pkg.name for pkg in cache if pkg.is_upgradable]

def check_kernel_update(packages):
    kernel_prefixes = ('linux-image', 'linux-headers', 'linux-modules', 'linux-firmware')
    for pkg in packages:
        if pkg.startswith(kernel_prefixes):
            return True
    return False

def send_telegram_alert(server_name, packages, ips, bot_token, chat_ids, is_critical):
    qtd = len(packages)
    exemplos = ", ".join(packages[:5])
    mais_info = "..." if qtd > 5 else ""
    
    alerta_icone = "🚨 *CRÍTICO: ATUALIZAÇÃO DE KERNEL*" if is_critical else "⚠️ *Alerta de Atualização*"
    
    mensagem = (
        f"{alerta_icone}\n"
        f"🖥️ *Servidor:* {server_name}\n"
        f"🌐 *IPs:* {ips}\n\n"
        f"Temos {qtd} pacotes prontos para atualizar.\n"
        f"📦 Alguns deles: {exemplos}{mais_info}"
    )
    
    url = f"https://api.telegram.org/{bot_token}/sendMessage"
    for chat_id in chat_ids:
        try:
            response = requests.post(url, json={"chat_id": chat_id, "text": mensagem, "parse_mode": "Markdown"})
            response.raise_for_status()
            logging.info(f"Telegram enviado com sucesso para Chat ID: {chat_id}")
        except Exception as e:
            logging.error(f"Falha ao enviar Telegram para Chat ID {chat_id}: {e}")

def send_email_alert(server_name, packages, ips, email_config, is_critical):
    if not email_config or not email_config.get("server"):
        return

    qtd = len(packages)
    lista_pacotes_html = "".join([f"<li>{pkg}</li>" for pkg in packages])
    
    cor_destaque = "#d9534f" if is_critical else "#0275d8"
    titulo_email = "🚨 URGENTE: ATUALIZAÇÃO CRÍTICA DE KERNEL" if is_critical else "ℹ️ Relatório de Atualizações APT"
    assunto = f"[{server_name}] {'🚨 CRÍTICO: Kernel Update' if is_critical else 'Atualizações Disponíveis'}"

    html_content = f"""
    <html>
    <body style="font-family: Arial, sans-serif; color: #333; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #ddd; border-radius: 8px;">
        <h2 style="color: {cor_destaque}; border-bottom: 2px solid {cor_destaque}; padding-bottom: 10px;">
            {titulo_email}
        </h2>
        <p><strong>Servidor:</strong> {server_name}</p>
        <p><strong>Endereços IP:</strong> {ips}</p>
        <div style="background-color: #f9f9f9; padding: 15px; border-left: 4px solid {cor_destaque}; margin: 20px 0;">
            <p style="margin: 0; font-size: 16px;">Existem <strong>{qtd}</strong> pacotes aguardando instalação neste servidor.</p>
        </div>
        <h3>Lista de Pacotes:</h3>
        <ul style="background-color: #f1f1f1; padding: 15px 35px; border-radius: 5px; max-height: 300px; overflow-y: auto;">
            {lista_pacotes_html}
        </ul>
        <hr style="border: 0; border-top: 1px solid #eee; margin-top: 30px;">
        <p style="font-size: 12px; color: #777; text-align: center;">Gerado automaticamente pelo APT Monitor Daemon</p>
    </body>
    </html>
    """

    msg = MIMEMultipart("alternative")
    msg["Subject"] = assunto
    msg["From"] = email_config["sender"]
    msg["To"] = ", ".join(email_config["recipients"])
    msg.attach(MIMEText(html_content, "html"))

    try:
        if email_config["port"] == 465:
            with smtplib.SMTP_SSL(email_config["server"], email_config["port"]) as server:
                server.login(email_config["user"], email_config["pass"])
                server.sendmail(email_config["sender"], email_config["recipients"], msg.as_string())
        else:
            with smtplib.SMTP(email_config["server"], email_config["port"]) as server:
                server.starttls()
                server.login(email_config["user"], email_config["pass"])
                server.sendmail(email_config["sender"], email_config["recipients"], msg.as_string())
        
        logging.info(f"E-mail enviado com sucesso para: {', '.join(email_config['recipients'])}")
    except Exception as e:
        logging.error(f"Falha ao enviar E-mail via {email_config['server']}:{email_config['port']} - {e}")

def main():
    bot_token, chat_ids, horas_rotacao, email_config = load_config()
    check_interval_seconds = int(horas_rotacao * 3600)
    server_name = socket.gethostname()
    last_notified_count = -1
    
    logging.info(f"=== Iniciando serviço APT Monitor em {server_name} ===")
    logging.info(f"Intervalo de checagem configurado: {horas_rotacao} hora(s)")
    
    while True:
        pacotes = get_upgradable_packages()
        qtd_atual = len(pacotes)
        
        if qtd_atual > 0 and qtd_atual != last_notified_count:
            ips = get_machine_ips()
            is_critical = check_kernel_update(pacotes)
            
            logging.info(f"Encontrados {qtd_atual} pacotes pendentes. Crítico (Kernel): {is_critical}")
            
            send_telegram_alert(server_name, pacotes, ips, bot_token, chat_ids, is_critical)
            send_email_alert(server_name, pacotes, ips, email_config, is_critical)
            
            last_notified_count = qtd_atual
        
        elif qtd_atual == 0 and last_notified_count != 0:
            logging.info("Todos os pacotes foram atualizados. Fila zerada e aguardando novas atualizações.")
            last_notified_count = 0
            
        time.sleep(check_interval_seconds)

if __name__ == "__main__":
    main()
