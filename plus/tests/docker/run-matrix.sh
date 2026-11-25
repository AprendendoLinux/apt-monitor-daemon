#!/bin/bash
# Uso: plus/tests/docker/run-matrix.sh [imagem ...]   (padrão: matriz Debian/Ubuntu)
# Constrói o clássico e o Plus e roda plus/tests/docker/inside.sh em cada imagem (inclui a migração clássico -> Plus).
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1
rm -f dist/*.deb plus/dist/*.deb      # nada de .deb antigo atrapalhando a escolha dos pacotes
./build.sh >/dev/null
plus/build.sh >/dev/null
IMAGES=("$@")
[ ${#IMAGES[@]} -gt 0 ] || IMAGES=(debian:11 debian:12 debian:13 ubuntu:20.04 ubuntu:22.04 ubuntu:24.04)
NETWORK=echelon; docker network inspect "$NETWORK" >/dev/null 2>&1 || NETWORK=bridge   # padrão do servidor; no CI usa a bridge
fail=0
for img in "${IMAGES[@]}"; do
    echo "################ $img"
    if docker run --rm --network "$NETWORK" -v "$PWD":/work:ro "$img" bash /work/plus/tests/docker/inside.sh > "/tmp/plus-matrix-${img//[:\/]/_}.log" 2>&1; then
        echo "OK   $img"
    else
        echo "FAIL $img  (veja /tmp/plus-matrix-${img//[:\/]/_}.log)"; tail -15 "/tmp/plus-matrix-${img//[:\/]/_}.log"; fail=1
    fi
done
exit $fail
