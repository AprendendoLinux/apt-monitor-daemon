# Contribuindo

Obrigado por ajudar! Contribuições de código, testes e documentação são bem-vindas.

## Ambiente

Só é preciso Python 3 e (para os testes de integração) Docker. Não há dependências de desenvolvimento.

```bash
python3 -m unittest discover -s tests -v   # unitários (segundos)
./build.sh                                  # gera dist/apt-monitor_<versão>_all.deb
tests/docker/run-matrix.sh [imagem...]      # instala o .deb em containers Debian/Ubuntu e exercita o fluxo
tests/docker/systemd-test.sh [imagem...]    # idem, com systemd real (container --privileged)
```

Imagens da matriz: `debian:11 debian:12 debian:13 ubuntu:20.04 ubuntu:22.04 ubuntu:24.04`.

## Regras do projeto

* **Compatibilidade:** o código precisa rodar em Python 3.6+ (sem `dataclasses`, sem `:=`, sem `subprocess.run(capture_output=...)`).
* **Sem dependências novas:** além de `python3-apt`, só biblioteca padrão.
* **Segredos:** nunca logue token, senha ou URLs completas da API do Telegram.
* **Scripts de manutenção** (`packaging/DEBIAN/*`) são `sh` POSIX e passam no `shellcheck`.
* **Testes:** todo bug corrigido ou funcionalidade nova vem com teste. O CI roda unitários, lint, a matriz de distros e o teste com systemd.

## Estrutura

```
src/                 código do daemon (um único arquivo)
packaging/           árvore do .deb (DEBIAN/, etc/, usr/)
build.sh             monta e gera o .deb
tests/               unitários e testes de integração (tests/docker/)
docs/                documentação
.github/workflows/   CI e release
```

## Como lançar uma versão

1. Atualize `__version__` em `src/apt_monitor.py` e o `CHANGELOG.md`.
2. Abra o PR e espere o CI ficar verde; faça o merge.
3. Crie a tag: `git tag vX.Y.Z && git push origin vX.Y.Z`. O workflow *Release* gera o `.deb` e o `SHA256SUMS` e
   publica em *Releases*.

## Commits e PRs

Mensagens objetivas em português ou inglês, explicando o *porquê*. PRs pequenos e focados são revisados mais rápido.
