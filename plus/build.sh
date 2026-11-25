#!/bin/bash
# Gera plus/dist/apt-monitor-plus_<versão>_all.deb a partir de plus/src e plus/packaging.
# Uso: plus/build.sh         (versão lida de plus/src/apt_monitor.py)
set -euo pipefail
cd "$(dirname "$0")" || exit 1

UPSTREAM=$(sed -n 's/^__version__ = "\(.*\)"/\1/p' src/apt_monitor.py)
VERSION="${UPSTREAM%.0}-1"          # 1.0.0 -> 1.0-1
[ -n "$UPSTREAM" ] || { echo "não achei __version__" >&2; exit 1; }
PKG="apt-monitor-plus_${VERSION}_all"
STAGE="build/$PKG"

rm -rf build "dist/$PKG.deb"
mkdir -p "$STAGE" dist
cp -a packaging/. "$STAGE/"

DOC="$STAGE/usr/share/doc/apt-monitor-plus"
install -d -m 0755 "$STAGE/usr/lib/apt-monitor-plus" "$STAGE/usr/sbin" "$DOC" "$DOC/examples"
install -m 0755 src/apt_monitor.py "$STAGE/usr/lib/apt-monitor-plus/apt_monitor.py"
ln -s ../lib/apt-monitor-plus/apt_monitor.py "$STAGE/usr/sbin/apt-monitor-plus"
ln -s ../lib/apt-monitor-plus/apt_monitor.py "$STAGE/usr/sbin/apt-monitor"      # atalho: mesmo comando do clássico
install -d -m 0750 "$STAGE/var/lib/apt-monitor-plus"
install -m 0644 README.md "$DOC/README.md"
install -m 0644 packaging/etc/apt-monitor-plus/apt-monitor.conf "$DOC/examples/apt-monitor.conf"
install -d -m 0755 "$DOC/docs"
install -m 0644 docs/*.md "$DOC/docs/"
# Changelog no formato Debian (o histórico completo está em CHANGELOG.md / README)
MAINT=$(sed -n 's/^Maintainer: //p' packaging/DEBIAN/control.in)
DATE=$(date -R -u -d "@${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct 2>/dev/null || date +%s)}")
cat > "$DOC/changelog.Debian" <<CHG
apt-monitor-plus ($VERSION) unstable; urgency=medium

  * Veja plus/CHANGELOG.md no repositório para a lista completa de mudanças.

 -- $MAINT  $DATE
CHG
gzip -9n "$DOC/changelog.Debian"
gzip -9n "$STAGE/usr/share/man/man8/apt-monitor-plus.8"

# control: versão e tamanho
SIZE=$(du -sk --exclude=DEBIAN "$STAGE" | cut -f1)
sed -e "s/@VERSION@/$VERSION/" -e "s/@SIZE@/$SIZE/" "$STAGE/DEBIAN/control.in" > "$STAGE/DEBIAN/control"
rm "$STAGE/DEBIAN/control.in"

# md5sums (permite 'debsums')
(cd "$STAGE" && find . -type f ! -path './DEBIAN/*' -printf '%P\0' | sort -z | xargs -0 md5sum > DEBIAN/md5sums)

# permissões
find "$STAGE" -type d -exec chmod 0755 {} +
chmod 0750 "$STAGE/var/lib/apt-monitor-plus"
find "$STAGE" -type f ! -path "*/DEBIAN/*" -exec chmod 0644 {} +
chmod 0755 "$STAGE/usr/lib/apt-monitor-plus/apt_monitor.py"
chmod 0600 "$STAGE/etc/apt-monitor-plus/apt-monitor.conf"
chmod 0755 "$STAGE"/DEBIAN/{postinst,prerm,postrm}
chmod 0644 "$STAGE/DEBIAN/conffiles"

# -Zxz: compressão compatível com Debian/Ubuntu antigos
if dpkg-deb --help 2>&1 | grep -q -- --root-owner-group; then
    dpkg-deb --root-owner-group -Zxz --build "$STAGE" "dist/$PKG.deb"
else
    fakeroot dpkg-deb -Zxz --build "$STAGE" "dist/$PKG.deb"
fi
echo "Gerado: dist/$PKG.deb"
