import apt
import requests
import time
import socket
import subprocess
import configparser
import os
import sys

CONFIG_FILE = "/etc/apt-monitor/apt-monitor.conf"

def load_config():
    """Lê o token, as IDs e o intervalo de rotação do ficheiro de configuração."""
    config = configparser.ConfigParser()
    if not os.path.exists(CONFIG_FILE):
        print(f"Erro: Ficheiro {CONFIG_FILE} não encontrado.")
        sys.exit(1)
    
    config.read(CONFIG_FILE)
    try:
        bot_token = config.get("Telegram", "BOT_TOKEN")
        chat_ids_str = config.get("Telegram", "CHAT_IDS")
        # Divide por vírgula e remove espaços em branco
        chat_ids = [cid.strip() for cid in chat_ids_str.split(",") if cid.strip()]
        
        # Lê o tempo de rotação da nova secção
        try:
            horas_rotacao = config.getfloat("Monitor", "CHECK_INTERVAL_HOURS")
        except (configparser.NoOptionError, configparser.NoSectionError):
            # Se a pessoa apagar a linha no .conf por engano, assume 4 horas por omissão
            horas_rotacao = 4.0 
            
        return bot_token, chat_ids, horas_rotacao
    except (configparser.NoOptionError, configparser.NoSectionError) as e:
        print(f"Erro na estrutura do ficheiro conf: {e}")
        sys.exit(1)

def get_machine_ips():
    try:
        output = subprocess.check_output(['hostname', '-I'], text=True).strip()
        ips = output.split()
        return ", ".join(ips) if ips else "Nenhum IP detetado"
    except Exception as e:
        return f"Erro ao obter IPs: {e}"

def get_upgradable_packages():
    cache = apt.Cache()
    try:
        cache.update()
        cache.open(None)
    except Exception as e:
        print(f"Erro ao atualizar o cache: {e}")
        return []
    return [pkg.name for pkg in cache if pkg.is_upgradable]

def send_telegram_alert(server_name, packages, ips, bot_token, chat_ids):
    qtd = len(packages)
    exemplos = ", ".join(packages[:5])
    mais_info = "..." if qtd > 5 else ""
    
    mensagem = (
        f"⚠️ *Alerta de Atualização - {server_name}*\n"
        f"🌐 *IPs:* {ips}\n\n"
        f"Temos {qtd} pacotes prontos para atualizar.\n"
        f"📦 Alguns deles: {exemplos}{mais_info}"
    )
    
    url = f"https://api.telegram.org/{bot_token}/sendMessage"
    
    for chat_id in chat_ids:
        payload = {
            "chat_id": chat_id,
            "text": mensagem,
            "parse_mode": "Markdown"
        }
        try:
            response = requests.post(url, json=payload)
            response.raise_for_status()
            print(f"Alerta enviado para o Chat ID {chat_id}.")
        except Exception as e:
            print(f"Erro ao enviar para o Chat ID {chat_id}: {e}")

def main():
    bot_token, chat_ids, horas_rotacao = load_config()
    
    # Converte as horas lidas do ficheiro para segundos (usado pelo time.sleep)
    check_interval_seconds = int(horas_rotacao * 3600)
    
    server_name = socket.gethostname()
    last_notified_count = -1
    
    print(f"A iniciar APT Monitor no servidor {server_name}...")
    print(f"A notificar os IDs: {', '.join(chat_ids)}")
    print(f"Intervalo de rotação configurado para: {horas_rotacao} hora(s) ({check_interval_seconds} segundos).")
    
    while True:
        pacotes = get_upgradable_packages()
        qtd_atual = len(pacotes)
        
        if qtd_atual > 0 and qtd_atual != last_notified_count:
            ips = get_machine_ips()
            send_telegram_alert(server_name, pacotes, ips, bot_token, chat_ids)
            last_notified_count = qtd_atual
        elif qtd_atual == 0:
            last_notified_count = 0
            
        time.sleep(check_interval_seconds)

if __name__ == "__main__":
    main()
