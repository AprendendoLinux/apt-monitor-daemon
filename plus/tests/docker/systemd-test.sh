#!/bin/bash
# Teste com systemd real (container privilegiado). Uso: plus/tests/docker/systemd-test.sh [debian:12|ubuntu:24.04 ...]
set -uo pipefail
cd "$(dirname "$0")/../../.." || exit 1
rm -f dist/*.deb plus/dist/*.deb      # nada de .deb antigo atrapalhando a escolha dos pacotes
./build.sh >/dev/null
plus/build.sh >/dev/null
IMAGES=("$@"); [ ${#IMAGES[@]} -gt 0 ] || IMAGES=(debian:12 ubuntu:24.04)
NETWORK=echelon; docker network inspect "$NETWORK" >/dev/null 2>&1 || NETWORK=bridge
rc=0
for base in "${IMAGES[@]}"; do
    tag="aptmonplus-systemd-${base//[:\/]/-}"; name="$tag-run"
    echo "################ $base (systemd)"
    docker build -q -t "$tag" - >/dev/null <<DOCKER
FROM $base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get install -y -qq systemd systemd-sysv dbus python3-apt apt-utils iproute2 ca-certificates dpkg-dev python3-requests logrotate tzdata >/dev/null
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
DOCKER
    docker rm -f "$name" >/dev/null 2>&1
    docker run -d --name "$name" --network "$NETWORK" --privileged --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
        --tmpfs /run --tmpfs /run/lock -v "$PWD":/work:ro "$tag" >/dev/null
    for _ in $(seq 30); do docker exec "$name" systemctl is-system-running 2>/dev/null | grep -qE 'running|degraded' && break; sleep 1; done
    if docker exec "$name" bash /work/plus/tests/docker/inside-systemd.sh > "/tmp/plus-systemd-${base//[:\/]/_}.log" 2>&1; then
        echo "OK   $base"
    else
        echo "FAIL $base (veja /tmp/plus-systemd-${base//[:\/]/_}.log)"; tail -25 "/tmp/plus-systemd-${base//[:\/]/_}.log"; rc=1
    fi
    docker rm -f "$name" >/dev/null 2>&1
done
exit $rc
