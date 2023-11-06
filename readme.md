<!-- #!/usr/bin/env markdown
-*- coding: utf-8 -*-
region header
Copyright Torben Sickert (info["~at~"]torben.website) 16.12.2012

License
-------

This library written by Torben Sickert stand under a creative commons naming
3.0 unported license. See https://creativecommons.org/licenses/by/3.0/deed.de
endregion -->

Project status
--------------

[![npm](https://img.shields.io/npm/v/backup-rotation?color=%23d55e5d&label=npm%20package%20version&logoColor=%23d55e5d&style=for-the-badge)](https://www.npmjs.com/package/backup-rotation)
[![npm downloads](https://img.shields.io/npm/dy/backup-rotation.svg?style=for-the-badge)](https://www.npmjs.com/package/backup-rotation)

[![documentation website](https://img.shields.io/website-up-down-green-red/https/torben.website/backup-rotation.svg?label=documentation-website&style=for-the-badge)](https://torben.website/backup-rotation)

Use case
--------

This module provides backup rotation logic for arbitrary files.

Features
--------

- Daily, weekly and monthly backups as cronjob
- Local and remote backups supported
- Compressed backups (tar and gz is used).
- Backup file structure is completely adaptable.
- Configure an email address to get notified if your backup source isn't
  available.
- Works incrementally (can complete interrupted backups after reboot e.g., uses
  rsync)
- Completely configurable how long you plan to preserve your backup files
- Optionally use your own synchronisation, compression and/or cleanup tool

Usage
-----

Run this script daily to generate your configured backup file structure.

```sh
./backupRotation.sh
```

or after installation:

```sh
backup-rotation
```

Installation with yay from the arch user repository
-----------------------------------------------------

```sh
yay --sync backupRotation
```

Manual installation on any posix compatible operating system
------------------------------------------------------------

Copy the script file "backupRotation.sh" to "/usr/bin/backup-rotation" and the
provided timer and service files ("backupRotation.service" and
"backupRotation.timer") to "/etc/systemd/system/backup-rotation.service" and
"/etc/systemd/system/backup-rotation.timer" and enable services:

Enable service under systemd
----------------------------

```sh
systemctl enable backup-rotation.timer
```

to enable the backup logic. After running:

```sh
systemctl start backup-rotation.timer
```

you can see the worker running in your system logs and observe generated backup
files.

Configuration
-------------

Simply create a text file under "/etc/backupRotation" and insert bash code
which sets all options you want to overwrite.

<!-- region vim modline
vim: set tabstop=4 shiftwidth=4 expandtab:
vim: foldmethod=marker foldmarker=region,endregion:
endregion -->
