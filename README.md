
# APT Monitor Daemon 📦

Um daemon leve e independente, escrito em Python, que roda via `systemd` para monitorar atualizações de pacotes APT em servidores Debian/Ubuntu. Quando há pacotes disponíveis para atualização, ele envia alertas automáticos via Telegram e relatórios detalhados em HTML por e-mail.

## 🌟 Funcionalidades

* **Monitoramento Contínuo:** Roda em background como um serviço nativo do sistema operacional.
* **Alertas Inteligentes:** Avisa apenas uma vez por lote de atualizações, evitando repetições desnecessárias.
* **Múltiplos Destinatários:** Suporta o envio de alertas para várias IDs de usuários/grupos no Telegram e múltiplos endereços de e-mail.
* **Alertas Críticos de Kernel:** Detecta automaticamente pacotes de kernel e destaca o aviso como urgente (🚨).
* **Relatórios por E-mail:** Envia um resumo em HTML das atualizações, com suporte a SMTP via STARTTLS (porta 587) ou SSL nativo (porta 465).
* **Informações de Rede:** Inclui automaticamente o nome do servidor (hostname) e os IPs (IPv4 e IPv6) na mensagem, ignorando interfaces de loopback.
* **Proteção de Configurações:** Utiliza o sistema de `conffiles` do Debian, garantindo que suas credenciais não sejam sobrescritas ao atualizar a versão do pacote.
* **Logs e Auditoria:** Registra todas as atividades em `/var/log/apt-monitor.log`, com rotação semanal automática via `logrotate`.

## 🚀 Como funcionam os Alertas

### Telegram
Quando houver atualizações padrão, o bot enviará uma mensagem parecida com esta:

> ⚠️ **Alerta de Atualização**
> 🖥️ **Servidor:** saopaulo
> 🌐 **IPs:** 192.168.1.50, 10.0.0.5
>
> Temos 8 pacotes prontos para atualizar.
> 📦 Alguns deles: curl, libcurl4, python3-apt, tzdata, ufw...

Se houver uma **atualização de Kernel**, o alerta muda para o modo crítico:

> 🚨 **CRÍTICO: ATUALIZAÇÃO DE KERNEL**
> 🖥️ **Servidor:** saopaulo
> ...

### E-mail
Um relatório em HTML é gerado detalhando a quantidade de pacotes e listando o nome de cada um deles, com uma tarja visual azul (informativa) ou vermelha (crítica, caso envolva o Kernel).

## ⚙️ Configuração

O daemon lê as configurações a partir do arquivo `/etc/apt-monitor/apt-monitor.conf`. A estrutura do arquivo deve ser a seguinte:

```bash
[Telegram]
BOT_TOKEN=seu_bot_token_aqui
# Insira os Chat IDs separados por vírgula
CHAT_IDS=12345678, 87654321

[Monitor]
# Tempo de rotação e verificação em horas (aceita decimais, ex: 0.5 para 30 min)
CHECK_INTERVAL_HOURS=4

[Email]
# Deixe em branco ou comente as linhas se não quiser usar e-mail neste servidor
SMTP_SERVER=smtp.seuservidor.com
SMTP_PORT=587 # Use 587 para STARTTLS ou 465 para SSL
SMTP_USER=alerta@seuservidor.com
SMTP_PASS=sua_senha_segura
SENDER_EMAIL=alerta@seuservidor.com
# Insira os e-mails destinatários separados por vírgula
RECIPIENT_EMAILS=admin@seuservidor.com, suporte@seuservidor.com
```
## 🛠️ Como Compilar o Pacote (.deb)

Para garantir que o pacote possa ser instalado em **qualquer versão do Debian ou Ubuntu** (mesmo em servidores mais antigos), utilizamos a flag `-Zxz` no `dpkg-deb`. Isso força a compressão retrocompatível `xz`, evitando erros de pacotes modernos em sistemas legado.

Certifique-se de que os scripts de manutenção (`postinst` e `prerm`) e o script Python possuam permissão de execução (`chmod 755`).

Na raiz do projeto, execute:

```bash
dpkg-deb -Zxz --build apt-monitor_1.0-1_all
```
Isso gerará o arquivo `apt-monitor_1.0-1_all.deb`.

## 📦 Instalação e Uso

Transfira o arquivo `.deb` gerado para o servidor de destino e instale-o:

```bash
sudo dpkg -i apt-monitor_1.0-1_all.deb
```
*(Se faltar alguma dependência, o sistema avisará. Basta rodar `sudo apt-get install -f` para corrigir e concluir).*

Ao instalar, o pacote automaticamente:
1. Copia os arquivos para os diretórios corretos.
2. Registra o arquivo `.conf` para não ser sobrescrito no futuro.
3. Configura o `logrotate`.
4. Habilita e inicia o daemon no systemd.

### Comandos Úteis do Serviço

Para acompanhar o funcionamento em tempo real pelo log próprio:
```bash
tail -f /var/log/apt-monitor.log
```

Para verificar pelo systemd:
```bash
sudo journalctl -u apt-monitor -f
```

Para reiniciar o serviço (necessário após alterar o arquivo `.conf`):
```bash
sudo systemctl restart apt-monitor
```
## 🗑️ Desinstalação

Para remover o daemon do sistema de forma totalmente limpa:

```bash
sudo apt remove apt-monitor
```
*(O script `prerm` integrado cuidará de parar e desativar o serviço no systemd antes da remoção dos arquivos).*