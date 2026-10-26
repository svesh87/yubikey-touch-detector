# Debian package

`build-deb.sh` builds `yubikey-touch-detector_<version>-<rev>~<codename>_<arch>.deb` from an
upstream source checkout; `.github/workflows/deb.yml` runs it on Ubuntu 24.04 and publishes the
package as a release of this fork:

    gh workflow run deb.yml --ref deb -f version=1.15.0

Installs the binary, the systemd user units (`yubikey-touch-detector.service`, `.socket`), the
man page and `service.conf.example`. Enable for your user:

    mkdir -p ~/.config/yubikey-touch-detector
    cp /usr/share/doc/yubikey-touch-detector/service.conf.example ~/.config/yubikey-touch-detector/service.conf
    systemctl --user enable --now yubikey-touch-detector.service
