#!/bin/sh
# Build a .deb from a source checkout of yubikey-touch-detector.
#   packaging/deb/build-deb.sh SRC_DIR VERSION OUT_DIR
# Needs: go, libgpgme-dev, libnotify-dev, scdoc, dpkg-dev. Runtime dependencies are taken
# from the libraries the built binary actually links against.
set -eu

src=$(realpath "$1") version="$2" out=$(realpath -m "$3")
pkg=yubikey-touch-detector
revision="${DEB_REVISION:-1}"
arch=$(dpkg --print-architecture)
codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
deb_version="${version}-${revision}~${codename}"
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

cd "$src"
CGO_ENABLED=1 go build -trimpath -ldflags "-s -w -X main.version=${version}" -o "$root/build/$pkg" .
scdoc < "$pkg.1.scd" > "$root/build/$pkg.1"

install -Dm755 "$root/build/$pkg" "$root/pkg/usr/bin/$pkg"
install -Dm644 "$pkg.service" "$root/pkg/usr/lib/systemd/user/$pkg.service"
install -Dm644 "$pkg.socket" "$root/pkg/usr/lib/systemd/user/$pkg.socket"
install -Dm644 service.conf.example "$root/pkg/usr/share/doc/$pkg/service.conf.example"
install -Dm644 LICENSE "$root/pkg/usr/share/doc/$pkg/copyright"
install -Dm644 "$root/build/$pkg.1" "$root/pkg/usr/share/man/man1/$pkg.1"
gzip -9n "$root/pkg/usr/share/man/man1/$pkg.1"

# Depends: the package owning each shared library the binary needs.
depends=$(objdump -p "$root/pkg/usr/bin/$pkg" | awk '/NEEDED/ {print $2}' | while read -r lib; do
    path=$(ldconfig -p | awk -v l="$lib" '$1 == l && /x86-64|aarch64/ {print $NF; exit}')
    dpkg -S "$path" 2>/dev/null | head -n 1 | cut -d: -f1
done | sort -u | paste -sd, - | sed 's/,/, /g')

size=$(du -sk "$root/pkg" | cut -f1)
mkdir -p "$root/pkg/DEBIAN"
cat > "$root/pkg/DEBIAN/control" <<CONTROL
Package: $pkg
Version: $deb_version
Architecture: $arch
Maintainer: Sergei Sveshnikov <sergei@svesh.dev>
Depends: $depends
Installed-Size: $size
Section: utils
Priority: optional
Homepage: https://github.com/maximbaz/yubikey-touch-detector
Description: detect when a YubiKey is waiting for a touch
 Watches gpg, ssh-agent and pam-u2f and signals (desktop notification, Unix socket)
 when the YubiKey waits for a touch. Upstream build of maximbaz/yubikey-touch-detector,
 packaged for $codename.
CONTROL

mkdir -p "$out"
dpkg-deb --root-owner-group --build "$root/pkg" "$out/${pkg}_${deb_version}_${arch}.deb"
echo "built $out/${pkg}_${deb_version}_${arch}.deb (Depends: $depends)"
