<!-- #!/usr/bin/env markdown
-*- coding: utf-8 -*-
region header
Copyright Torben Sickert (info["~at~"]tsickert.com) 16.12.2012

License
-------

This library written by Torben Sickert stands under a creative commons naming
4.0 international license.
See https://creativecommons.org/licenses/by/4.0/deed.de
endregion -->

<!--|deDE:Projektstatus-->
<!--|frFR:Statut du projet-->
Project Status
--------------

[![npm](https://img.shields.io/npm/v/backup-rotation?color=%23d55e5d&label=npm%20package%20version&logoColor=%23d55e5d&style=for-the-badge)](https://www.npmjs.com/package/backup-rotation)
[![npm downloads](https://img.shields.io/npm/dy/backup-rotation.svg?style=for-the-badge)](https://www.npmjs.com/package/backup-rotation)

[![build push package](https://img.shields.io/github/actions/workflow/status/thaibault/backup-rotation/build-package-and-push.yaml?label=build%20push%20package&style=for-the-badge)](https://github.com/thaibault/backup-rotation/actions/workflows/build-package-and-push.yaml)

[![lint](https://img.shields.io/github/actions/workflow/status/thaibault/backup-rotation/lint.yaml?label=lint&style=for-the-badge)](https://github.com/thaibault/backup-rotation/actions/workflows/lint.yaml)
[![test](https://img.shields.io/github/actions/workflow/status/thaibault/backup-rotation/test.yaml?label=test&style=for-the-badge)](https://github.com/thaibault/backup-rotation/actions/workflows/test.yaml)

[![deploy web documentation](https://img.shields.io/github/actions/workflow/status/thaibault/backup-rotation/deploy-web-documentation.yaml?label=deploy%20web%20documentation&style=for-the-badge)](https://github.com/thaibault/backup-rotation/actions/workflows/deploy-web-documentation.yaml)
[![web documentation](https://img.shields.io/website-up-down-green-red/https/tsickert.com/backup-rotation.svg?label=web-documentation&style=for-the-badge)](https://tsickert.com/backup-rotation)

<!--|deDE:Einsatzmöglichkeiten-->
<!--|frFR:Cas d'utilisation-->
Use case
--------

Daily, weekly and monthly backups of any folders with a single Bash script
and a systemd timer. Each run copies the sources via rsync, packs them as
compressed archive, optionally encrypts them and removes backups older than
their retention time. Recipients get an e-mail on failures (and optionally on
success), a monitoring service can be informed as well.
<!--deDE:
    Tägliche, wöchentliche und monatliche Sicherungen beliebiger Ordner mit
    einem einzigen Bash-Skript und einem systemd-Timer. Jeder Lauf kopiert
    die Quellen über rsync, packt sie als komprimiertes Archiv, verschlüsselt
    sie optional und entfernt Sicherungen, die älter als ihre
    Aufbewahrungszeit sind. Empfänger erhalten bei Fehlern (und optional bei
    Erfolg) eine E-Mail, zusätzlich kann ein Monitoring-Dienst informiert
    werden.
-->
<!--frFR:
    Des sauvegardes quotidiennes, hebdomadaires et mensuelles de n'importe
    quels dossiers avec un seul script Bash et un timer systemd. Chaque
    exécution copie les sources via rsync, les empaquette en archive
    compressée, les chiffre éventuellement et supprime les sauvegardes plus
    anciennes que leur durée de conservation. Les destinataires reçoivent un
    e-mail en cas d'échec (et éventuellement en cas de succès), un service de
    supervision peut aussi être informé.
-->

<div class="wd-table-of-contents">
    <h2 id="content">Content<!--deDE:Inhalt--><!--frFR:Contenu--></h2>
    <!--wd-table-of-contents-->
</div>

Installation
------------

Copy the script and the systemd units into place and enable the timer, which
runs the backup every night at 01:00 (Europe/Berlin):
<!--deDE:
    Kopieren Sie das Skript und die systemd-Units an ihren Platz und
    aktivieren Sie den Timer, der die Sicherung jede Nacht um 01:00 Uhr
    (Europe/Berlin) startet:
-->
<!--frFR:
    Copiez le script et les unités systemd à leur place et activez le timer,
    qui lance la sauvegarde chaque nuit à 01h00 (Europe/Berlin):
-->

```bash
install -D --mode 755 backup-rotation.sh /usr/bin/backup-rotation
install -D --mode 644 backup-rotation.service backup-rotation.timer \
    --target-directory /etc/systemd/system
systemctl enable --now backup-rotation.timer
```

On Arch Linux the included "PKGBUILD" builds a package via "makepkg
--install". The script needs "bash", "rsync", "tar" and "find" and downloads
its library [bashlink](https://tsickert.com/bashlink) if it is not
installed. It is also available via "npm install backup-rotation".
<!--deDE:
    Unter Arch Linux baut das enthaltene "PKGBUILD" über "makepkg --install"
    ein Paket. Das Skript benötigt "bash", "rsync", "tar" und "find" und lädt
    seine Bibliothek [bashlink](https://tsickert.com/bashlink) herunter, wenn
    sie nicht installiert ist. Es ist auch über "npm install backup-rotation"
    erhältlich.
-->
<!--frFR:
    Sous Arch Linux, le "PKGBUILD" inclus construit un paquet via "makepkg
    --install". Le script nécessite "bash", "rsync", "tar" et "find" et
    télécharge sa bibliothèque [bashlink](https://tsickert.com/bashlink) si
    elle n'est pas installée. Il est aussi disponible via
    "npm install backup-rotation".
-->

Configuration
-------------

"/etc/backupRotation" is a Bash file which overrides the defaults. At least
the sources have to be mapped to their target folders, optionally followed by
e-mail addresses to notify:
<!--deDE:
    "/etc/backupRotation" ist eine Bash-Datei, die die Standardwerte
    überschreibt. Mindestens müssen die Quellen ihren Zielordnern zugeordnet
    werden, optional gefolgt von zu benachrichtigenden E-Mail-Adressen:
-->
<!--frFR:
    "/etc/backupRotation" est un fichier Bash qui remplace les valeurs par
    défaut. Il faut au minimum associer les sources à leurs dossiers cibles,
    éventuellement suivis d'adresses e-mail à notifier:
-->

```bash
BR_SOURCE_TARGET_MAPPINGS=(
    ['/home']='/mnt/backup/home admin@example.com'
    ['server:/srv/data']='/mnt/backup/data'
)
BR_NAME=workstation
```

Sources can be anything rsync accepts, also remote locations like
"server:/srv/data". Targets have to be local folders, e.g. a mounted disk or
network share. "BR_NAME" names this machine in reports. Run
"backup-rotation" once by hand to check the configuration.
<!--deDE:
    Quellen können alles sein, was rsync akzeptiert, auch entfernte Orte wie
    "server:/srv/data". Ziele müssen lokale Ordner sein, z. B. eine
    eingehängte Festplatte oder Netzwerkfreigabe. "BR_NAME" benennt diesen
    Rechner in Berichten. Führen Sie "backup-rotation" einmal von Hand aus,
    um die Konfiguration zu prüfen.
-->
<!--frFR:
    Les sources peuvent être tout ce que rsync accepte, y compris des
    emplacements distants comme "server:/srv/data". Les cibles doivent être
    des dossiers locaux, par exemple un disque monté ou un partage réseau.
    "BR_NAME" nomme cette machine dans les rapports. Lancez "backup-rotation"
    une fois à la main pour vérifier la configuration.
-->

<!--|deDE:Rotation-->
<!--|frFR:Rotation-->
### Rotation

Each target gets the folders "daily", "weekly" and "monthly". On the first
day of the month the backup goes to "monthly", on Saturdays to "weekly",
otherwise to "daily". Daily (and weekly) backups of these days are links to
it. Backups are kept for 14, 56 and 365 days:
<!--deDE:
    Jedes Ziel erhält die Ordner "daily", "weekly" und "monthly". Am ersten
    Tag des Monats landet die Sicherung in "monthly", samstags in "weekly",
    sonst in "daily". Tägliche (und wöchentliche) Sicherungen dieser Tage
    sind Verknüpfungen darauf. Sicherungen werden 14, 56 und 365 Tage
    aufbewahrt:
-->
<!--frFR:
    Chaque cible reçoit les dossiers "daily", "weekly" et "monthly". Le
    premier jour du mois, la sauvegarde va dans "monthly", le samedi dans
    "weekly", sinon dans "daily". Les sauvegardes quotidiennes (et
    hebdomadaires) de ces jours sont des liens vers celle-ci. Les sauvegardes
    sont conservées 14, 56 et 365 jours:
-->

```bash
BR_MONTH_DAY_NUMBER=1
BR_WEEK_DAY_NUMBER=6
BR_NUMBER_OF_DAILY_RETENTION_DAYS=14
BR_NUMBER_OF_WEEKLY_RETENTION_DAYS=56
BR_NUMBER_OF_MONTHLY_RETENTION_DAYS=365
```

Outdated backups are only removed after a successful run, so a failing
source never loses its last backups.
<!--deDE:
    Veraltete Sicherungen werden nur nach einem erfolgreichen Lauf entfernt,
    sodass eine fehlerhafte Quelle nie ihre letzten Sicherungen verliert.
-->
<!--frFR:
    Les sauvegardes obsolètes ne sont supprimées qu'après une exécution
    réussie, de sorte qu'une source en échec ne perd jamais ses dernières
    sauvegardes.
-->

<!--|deDE:Verschlüsselung-->
<!--|frFR:Chiffrement-->
### Encryption

If the password file "/etc/backupRotationPassword" is not empty, archives
are encrypted with "gpg" and get the extension ".tar.gz.gpg". Decrypt one
with:
<!--deDE:
    Ist die Passwortdatei "/etc/backupRotationPassword" nicht leer, werden
    Archive mit "gpg" verschlüsselt und erhalten die Endung ".tar.gz.gpg".
    Entschlüsseln Sie eines mit:
-->
<!--frFR:
    Si le fichier de mot de passe "/etc/backupRotationPassword" n'est pas
    vide, les archives sont chiffrées avec "gpg" et reçoivent l'extension
    ".tar.gz.gpg". Déchiffrez-en une avec:
-->

```bash
gpg --decrypt --output backup.tar.gz 13-11-2026.tar.gz.gpg
```

<!--|deDE:Benachrichtigungen-->
<!--|frFR:Notifications-->
### Notifications

E-mails are sent via "msmtp", so it needs a working "/etc/msmtprc". Without
"BR_SENDER_E_MAIL_ADDRESS" no e-mails are sent. "BR_MONITORING_URL" receives
a JSON document with "source", "target" and "error" via "PUT" after each
backup:
<!--deDE:
    E-Mails werden über "msmtp" verschickt, es braucht also eine
    funktionierende "/etc/msmtprc". Ohne "BR_SENDER_E_MAIL_ADDRESS" werden
    keine E-Mails versandt. "BR_MONITORING_URL" erhält nach jeder Sicherung
    ein JSON-Dokument mit "source", "target" und "error" per "PUT":
-->
<!--frFR:
    Les e-mails sont envoyés via "msmtp", il faut donc un "/etc/msmtprc"
    fonctionnel. Sans "BR_SENDER_E_MAIL_ADDRESS", aucun e-mail n'est envoyé.
    "BR_MONITORING_URL" reçoit après chaque sauvegarde un document JSON avec
    "source", "target" et "error" via "PUT":
-->

```bash
BR_SENDER_E_MAIL_ADDRESS=backup@example.com
BR_SEND_SUCCESS_E_MAILS=false
BR_MONITORING_URL=https://monitoring.example.com/backups
```

<!--|deDE:Eigene Befehle-->
<!--|frFR:Commandes personnalisées-->
### Own commands

"BR_COMMAND" replaces the rsync and tar step, "BR_ENCRYPT_COMMAND" the
encryption and "BR_CLEANUP_COMMAND" the removal of outdated backups.
"BR_POST_RUN_COMMAND" runs after each successful backup and its result is
reported. Commands can use "$source_path", "$target_path" and
"$target_file_basepath" (the backup file path without extension).
"BR_VERBOSE=true" prints what happens.
<!--deDE:
    "BR_COMMAND" ersetzt den Schritt mit rsync und tar, "BR_ENCRYPT_COMMAND"
    die Verschlüsselung und "BR_CLEANUP_COMMAND" das Entfernen veralteter
    Sicherungen. "BR_POST_RUN_COMMAND" läuft nach jeder erfolgreichen
    Sicherung, sein Ergebnis wird mitgeteilt. Befehle können
    "$source_path", "$target_path" und "$target_file_basepath" (den Pfad der
    Sicherungsdatei ohne Endung) verwenden. "BR_VERBOSE=true" gibt aus, was
    passiert.
-->
<!--frFR:
    "BR_COMMAND" remplace l'étape rsync et tar, "BR_ENCRYPT_COMMAND" le
    chiffrement et "BR_CLEANUP_COMMAND" la suppression des sauvegardes
    obsolètes. "BR_POST_RUN_COMMAND" s'exécute après chaque sauvegarde
    réussie et son résultat est signalé. Les commandes peuvent utiliser
    "$source_path", "$target_path" et "$target_file_basepath" (le chemin du
    fichier de sauvegarde sans extension). "BR_VERBOSE=true" affiche ce qui
    se passe.
-->

```bash
BR_POST_RUN_COMMAND='rclone copy "$target_path" remote:backups'
```

<!--|deDE:Entwicklung-->
<!--|frFR:Développement-->
Development
-----------

```bash
yarn install
yarn lint
yarn test
```
