#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# Copyright Torben Sickert (info["~at~"]torben.website) 16.12.2012

# License
# -------

# This library written by Torben Sickert stand under a creative commons naming
# 3.0 unported license. see http://creativecommons.org/licenses/by/3.0/deed.de
# endregion
pkgname=backupRotation
pkgver=1.0
pkgrel=1
pkgdesc='This script allows you to create a local or remote backup rotation for your files.'
arch=('any')
url='http://torben.website/backupRotation'
license=('CC-BY-3.0')
depends=('pacman' 'yaourt' 'rsync' 'findutils')
source=('backupRotation.sh')
md5sums=('SKIP')

package() {
    install -D --mode 755 backupRotation.sh "${pkgdir}/usr/bin/backupRotation"
}
# region vim modline
# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:
# endregion
