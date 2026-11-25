# Contribuindo

Obrigado por ajudar! Contribuições de código, testes e documentação são bem-vindas.

## Duas edições, um repositório

| | Clássico | Plus |
|---|---|---|
| Código | `src/` | `plus/src/` |
| Empacotamento | `packaging/`, `build.sh` | `plus/packaging/`, `plus/build.sh` |
| Testes | `tests/` | `plus/tests/` |
| Documentação | `docs/`, `README.md` | `plus/docs/`, `plus/README.md` |
| Changelog | `CHANGELOG.md` | `plus/CHANGELOG.md` |
| Tag de release | `vX.Y.Z` | `plus-vX.Y.Z` |
| Pacote | `apt-monitor` | `apt-monitor-plus` |

Cada edição é **autocontida** (um único arquivo Python, sem módulo compartilhado). O custo disso é que **uma correção
no núcleo (leitura do apt, classificação kernel/segurança, envio por Telegram/SMTP, configuração) precisa ser portada
para as duas**. Por isso:

* Ao abrir um PR que corrige algo no núcleo, diga no PR se vale também para a **outra edição** e, se sim, faça o port
  no mesmo PR ou abra uma issue com o rótulo `also-plus` / `also-classic`.
* Funcionalidades **só do Plus** (relatório ao cliente, histórico SQLite, detecção imediata, e-mails novos) ficam
  em `plus/` e não entram no clássico, salvo decisão explícita.
* Os guias de **Telegram** e **SMTP** (`docs/telegram.md`, `docs/email.md`) são compartilhados: o Plus aponta para eles.
* Os dois pacotes **não coexistem** (`Conflicts`): o Plus substitui o clássico e migra a configuração
  (`plus/docs/migracao.md`). Mudanças em caminhos, nomes de serviço ou no `postinst` do Plus exigem rodar também a
  migração nos testes de integração.

## Ambiente

Só é preciso Python 3 e (para os testes de integração) Docker. Não há dependências de desenvolvimento.

```bash
# Clássico
python3 -m unittest discover -s tests -v   # unitários (segundos)
./build.sh                                  # gera dist/apt-monitor_<versão>_all.deb
tests/docker/run-matrix.sh [imagem...]      # instala o .deb em containers Debian/Ubuntu e exercita o fluxo
tests/docker/systemd-test.sh [imagem...]    # idem, com systemd real (container --privileged)

# Plus
python3 -m unittest discover -s plus/tests -v   # unitários
plus/build.sh                                    # gera plus/dist/apt-monitor-plus_<versão>_all.deb
plus/tests/docker/run-matrix.sh [imagem...]      # idem, incluindo a migração clássico -> Plus e o relatório
plus/tests/docker/systemd-test.sh [imagem...]    # idem, com systemd real (detecção imediata, relatório no horário)
plus/tests/render/run.sh                         # renderiza os e-mails num Chromium (contêiner) e salva capturas
```

Imagens da matriz: `debian:11 debian:12 debian:13 ubuntu:20.04 ubuntu:22.04 ubuntu:24.04`.

## Regras do projeto

* **Compatibilidade:** o código precisa rodar em Python 3.6+ (sem `dataclasses`, sem `:=`, sem `subprocess.run(capture_output=...)`).
* **Sem dependências novas:** além de `python3-apt`, só biblioteca padrão.
* **Segredos:** nunca logue token, senha ou URLs completas da API do Telegram.
* **Scripts de manutenção** (`packaging/DEBIAN/*` e `plus/packaging/DEBIAN/*`) são `sh` POSIX e passam no `shellcheck`.
* **E-mails (Plus):** mudou o visual? Rode `plus/tests/render/run.sh` e confira as capturas no desktop e no celular.
* **Testes:** todo bug corrigido ou funcionalidade nova vem com teste. O CI roda unitários, lint, a matriz de distros e o teste com systemd.

## Estrutura

```
src/  packaging/  build.sh  tests/  docs/     APT Monitor clássico
plus/                                         APT Monitor Plus
  src/  packaging/  build.sh  tests/  docs/
  tests/render/                               capturas dos e-mails (Chromium em contêiner)
.github/workflows/                            CI e releases (um workflow de release por edição)
```

## Como lançar uma versão

**Clássico**

1. Atualize `__version__` em `src/apt_monitor.py` e o `CHANGELOG.md`.
2. Abra o PR e espere o CI ficar verde; faça o merge.
3. Crie a tag: `git tag vX.Y.Z && git push origin vX.Y.Z`. O workflow *Release* gera o `.deb` e o `SHA256SUMS` e
   publica em *Releases* (sem tomar o selo "Latest", que é do Plus).

**Plus**

1. Atualize `__version__` em `plus/src/apt_monitor.py` e o `plus/CHANGELOG.md`.
2. Abra o PR e espere o CI ficar verde; faça o merge.
3. Crie a tag: `git tag plus-vX.Y.Z && git push origin plus-vX.Y.Z`. O workflow *Release Plus* confere que a tag bate
   com a versão do código, gera o `apt-monitor-plus_*.deb` e o `SHA256SUMS` e publica em *Releases* como **Latest**.

## Commits e PRs

Mensagens objetivas em português ou inglês, explicando o *porquê*. PRs pequenos e focados são revisados mais rápido.
