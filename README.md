# APT Monitor Daemon 📦

Um daemon leve e independente, escrito em Python, que roda via `systemd` para monitorar atualizações de pacotes APT em servidores Debian/Ubuntu. Quando há pacotes disponíveis para atualização, ele envia alertas automáticos via Telegram.

## 🌟 Funcionalidades

* **Monitoramento Contínuo:** Roda em background como um serviço nativo do sistema operacional.
* **Alertas Inteligentes:** Avisa apenas uma vez por lote de atualizações, evitando spam no seu chat.
* **Múltiplos Destinatários:** Suporta o envio de alertas para várias IDs de usuários ou grupos no Telegram.
* **Informações de Rede:** Inclui automaticamente o nome do servidor (hostname) e os IPs (IPv4 e IPv6) na mensagem, ignorando interfaces de loopback.
* **Configuração Flexível:** Arquivo `.conf` externo para ajustar tokens, IDs e o intervalo de rotação por horas, sem precisar mexer no código fonte.
* **Empacotamento Nativo:** Distribuído via pacote `.deb` com scripts de `postinst` e `prerm` para gerenciar o daemon automaticamente na instalação e remoção.

---

## 🚀 Como funciona o Alerta

Quando houver atualizações, o bot enviará uma mensagem parecida com esta:

> ⚠️ **Alerta de Atualização - saopaulo**
> 🌐 **IPs:** 192.168.1.50, 10.0.0.5
>
> Temos 8 pacotes prontos para atualizar.
> 📦 Alguns deles: curl, libcurl4, python3-apt, tzdata, ufw...

---

## ⚙️ Configuração

O daemon lê as configurações a partir do arquivo `/etc/apt-monitor/apt-monitor.conf`. A estrutura do arquivo deve ser a seguinte:

```ini
[Telegram]
BOT_TOKEN=seu_bot_token_aqui
# Insira os Chat IDs separados por vírgula
CHAT_IDS=12345678, 87654321

[Monitor]
# Tempo de rotação e verificação em horas (aceita decimais, ex: 0.5 para 30 min)
CHECK_INTERVAL_HOURS=4
```

---

## 🛠️ Como Compilar o Pacote (.deb)

Para garantir que o pacote possa ser instalado em **qualquer versão do Debian ou Ubuntu** (mesmo em servidores mais antigos), utilizamos a flag `-Zxz` no `dpkg-deb`. Isso força a compressão retrocompatível `xz`, evitando erros de pacotes modernos (como o formato `.zst`) em sistemas legado.

Certifique-se de que os scripts de manutenção (`postinst` e `prerm`) e o script Python possuam permissão de execução (`chmod 755`).

Na raiz do projeto (um nível acima da pasta `apt-monitor_1.0-1_all`), execute:

```bash
dpkg-deb -Zxz --build apt-monitor_1.0-1_all
```

Isso gerará o arquivo `apt-monitor_1.0-1_all.deb`.

---

## 📦 Instalação e Uso

Transfira o arquivo `.deb` gerado para o servidor de destino e instale-o com o `dpkg`:

```bash
sudo dpkg -i apt-monitor_1.0-1_all.deb
```
*(Se faltar alguma dependência, o sistema avisará. Basta rodar `sudo apt-get install -f` para corrigir e concluir).*

Ao instalar, o pacote automaticamente:
1. Copia os arquivos para os diretórios corretos (`/opt`, `/etc`, etc.).
2. Cria o serviço no systemd.
3. Habilita e inicia o daemon.

### Comandos Úteis do Serviço

Para verificar os logs em tempo real e confirmar o envio das mensagens:
```bash
sudo journalctl -u apt-monitor -f
```

Para reiniciar o serviço (necessário após alterar o arquivo `.conf`):
```bash
sudo systemctl restart apt-monitor
```

Para verificar o status:
```bash
sudo systemctl status apt-monitor
```

---

## 🗑️ Desinstalação

Para remover o daemon do sistema de forma totalmente limpa (o script `prerm` cuidará de parar e desativar o serviço no systemd antes de apagar os arquivos):

```bash
sudo apt remove apt-monitor
```
