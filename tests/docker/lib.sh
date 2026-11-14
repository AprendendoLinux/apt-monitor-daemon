#!/bin/bash
# Funções comuns dos testes de integração em container.
export DEBIAN_FRONTEND=noninteractive
step(){ echo; echo "── $*"; }
ok(){ echo "  ✔ $*"; }
die(){ echo "  ✘ $*" >&2; exit 1; }
mock(){ python3 -I -c "import json,sys; d=json.load(open('/tmp/mock.json')); print(bool(eval(sys.argv[1])))" "$1"; }
settle(){ sleep 0.6; }
expect(){ # expect "descrição" "expressão python sobre d" 
  [ "$(mock "$2")" = "True" ] && ok "$1" || { echo "  mock.json:"; cat /tmp/mock.json; die "$1"; }; }

mkpkg(){ local d; d=$(mktemp -d); mkdir -p "$d/DEBIAN" "$3"
  printf 'Package: %s\nVersion: %s\nArchitecture: all\nMaintainer: t <t@t>\nDescription: demo %s\n' "$1" "$2" "$1" > "$d/DEBIAN/control"
  dpkg-deb -b "$d" "$3/$1_$2_all.deb" >/dev/null; }
mkrepo(){ (cd "$1" && apt-ftparchive packages . > Packages && apt-ftparchive -o "APT::FTPArchive::Release::Suite=$2" release . > Release)
  echo "deb [trusted=yes] file:$1 ./" > "/etc/apt/sources.list.d/$(basename "$1").list"; }
