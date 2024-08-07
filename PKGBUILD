#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# Copyright Torben Sickert (info["~at~"]torben.website) 16.12.2012

# License
# -------

# This library written by Torben Sickert stand under a creative commons naming
# 3.0 unported license. See https://creativecommons.org/licenses/by/3.0/deed.de
# endregion
pkgname=backup-rotation
pkgver=1.0.90
pkgrel=37
pkgdesc='This script allows you to create a local or remote backup rotation for your files.'
arch=(any)
url=https://torben.website/backupRotation
license=(CC-BY-3.0)
devdepends=(bashlink shellcheck)
depends=(bash rsync findutils)
optdepends=(
    'coreutils: for well formatted reportings about successful backup creations.'
    'curl: needed to send monitoring informations with advanced meta data.'
    'msmtp: for automatic email notifications on missing sources.'
    'sed: for well formatted reportings about successful backup creations.'
    'tree: for well formatted reportings about successful backup creations.'
)
provides=(backup-rotation)
source=(backupRotation.sh backupRotation.timer backupRotation.service)
md5sums=(SKIP SKIP SKIP)
copy_to_aur=true

package() {
    install -D --mode 644 "${srcdir}/backupRotation.service" \
        "${pkgdir}/etc/systemd/system/backup-rotation.service"
    install -D --mode 644 "${srcdir}/backupRotation.timer" \
        "${pkgdir}/etc/systemd/system/backup-rotation.timer"
    install -D --mode 755 "${srcdir}/backupRotation.sh" \
        "${pkgdir}/usr/bin/backup-rotation"
}
