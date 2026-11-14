#!/bin/bash
# Uso: tests/docker/run-matrix.sh [imagem ...]   (padrão: matriz Debian/Ubuntu)
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
./build.sh >/dev/null
IMAGES=("$@")
[ ${#IMAGES[@]} -gt 0 ] || IMAGES=(debian:11 debian:12 debian:13 ubuntu:20.04 ubuntu:22.04 ubuntu:24.04)
fail=0
for img in "${IMAGES[@]}"; do
    echo "################ $img"
    if docker run --rm -v "$PWD":/work:ro "$img" bash /work/tests/docker/inside.sh > "/tmp/matrix-${img//[:\/]/_}.log" 2>&1; then
        echo "OK   $img"
    else
        echo "FAIL $img  (veja /tmp/matrix-${img//[:\/]/_}.log)"; tail -15 "/tmp/matrix-${img//[:\/]/_}.log"; fail=1
    fi
done
exit $fail
