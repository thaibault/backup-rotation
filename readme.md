<!-- #!/usr/bin/env markdown
-*- coding: utf-8 -*- -->

<!-- region header

Copyright Torben Sickert 16.12.2012

License
-------

This library written by Torben Sickert stand under a creative commons naming
3.0 unported license. see http://creativecommons.org/licenses/by/3.0/deed.de

endregion -->

Use case
--------

This module provides backup rotation logic for arbitrary files.

Features
--------

- Daily, weekly and monthly backups as cronjob
- Local and remote backups supported
- Compressed backups (tar and gz is used).
- Works incrementally (can complete interrupted backups after reboot e.g., uses
  rsync)
- Completely configurable how long you plan to preserve your backup files
- Optionally use your own synchronisation, compression and/or cleanup tool

Usage
-----

Run this script daily to generate you configured backup file structure.

```sh
./backupRotation.sh
```

Configuration
-------------

Simply edit the constants region of the provided shell script.

Installation (under systemd)
----------------------------

Copy the script file "backupRotation.sh" to "/usr/local/bin/" and copy the
provided timer and service files (backupRotation.service and
backupRotation.timer) to "/etc/systemd/system/" and run

```sh
systemctl enable backupRotation.timer
```

to enable the backup logic. After running:

```sh
systemctl start backupRotation.timer
```

you can see the worker running in your system logs and observe generated backup
files.

<!-- region vim modline
vim: set tabstop=4 shiftwidth=4 expandtab:
vim: foldmethod=marker foldmarker=region,endregion:
endregion -->
