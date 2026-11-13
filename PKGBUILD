#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# Copyright Torben Sickert (info["~at~"]tsickert.com) 16.12.2012

# License
# -------

# This library written by Torben Sickert stands under a creative commons naming
# 4.0 international license.
# See https://creativecommons.org/licenses/by/4.0/deed.de
# endregion
pkgname=backup-rotation
pkgver=1.0.90
pkgrel=37
pkgdesc='This script allows you to create a local or remote backup rotation for your files.'
arch=(any)
url=https://tsickert.com/backup-rotation
license=(CC-BY-4.0)
devdepends=(bashlink shellcheck)
depends=(bash rsync findutils tar)
optdepends=(
    'coreutils: for well formatted reportings about successful backup creations.'
    'curl: needed to send monitoring informations with advanced meta data.'
    'gnupg: to encrypt backups.'
    'msmtp: for automatic email notifications on missing sources.'
    'sed: for well formatted reportings about successful backup creations.'
    'tree: for well formatted reportings about successful backup creations.'
)
provides=(backup-rotation)
source=(backup-rotation.sh backup-rotation.timer backup-rotation.service)
md5sums=(SKIP SKIP SKIP)
copy_to_aur=true

package() {
    install -D --mode 644 "${srcdir}/backup-rotation.service" \
        "${pkgdir}/etc/systemd/system/backup-rotation.service"
    install -D --mode 644 "${srcdir}/backup-rotation.timer" \
        "${pkgdir}/etc/systemd/system/backup-rotation.timer"
    install -D --mode 755 "${srcdir}/backup-rotation.sh" \
        "${pkgdir}/usr/bin/backup-rotation"
}
